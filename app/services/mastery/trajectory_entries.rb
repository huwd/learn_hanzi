module Mastery
  # Drill-down behind a single Trajectory bucket tile on /progress: which
  # DictionaryEntry words actually make it up, ranked by how firmly they
  # exemplify the label, with an explicit sort/direction override for
  # anything clicked on the table header. See #391, #400.
  #
  # Population per bucket -- Chronic/Recovering only ever contain
  # Established words (graduation_count >= 1 implies first_mastered_at is
  # set), Stalled only ever contains Developing words, and Stable spans
  # both. Each population is fetched independently so a Chronic/Recovering
  # request never touches the Developing rows (and its bounded
  # recent-eases query), and a Stalled request never touches Established
  # rows -- only Stable pays for both.
  #
  # Sorting and pagination both happen against lightweight [UserLearning,
  # coverage] candidates -- every sortable column except word/meaning
  # lives directly on user_learnings, so no join is needed to rank the
  # whole bucket. dictionary_entry/meanings are only ever hydrated for the
  # current page's ids, after pagination has already picked them, so a
  # large bucket costs no more per-request than a small one. Sorting by
  # word/meaning is the one case that needs text for the whole bucket
  # before ranking; that's a single lightweight lookup query (no
  # association hydration), not a switch back to loading everything.
  class TrajectoryEntries
    Entry = Data.define(:id, :text, :pinyin, :meaning, :coverage, :factor, :graduation_count, :since, :next_due)
    Result = Data.define(:entries, :total, :page, :per_page)

    PER_PAGE = 50
    MAX_PER_PAGE = 200

    SORTABLE_COLUMNS = %w[word meaning ease graduations since next_due].freeze

    def self.call(user:, bucket:, sort: nil, direction: nil, page: 1, per_page: PER_PAGE)
      new(user, bucket, sort, direction, page, per_page).call
    end

    def initialize(user, bucket, sort, direction, page, per_page)
      @user = user
      @bucket = bucket
      @sort = sort
      @direction = direction.to_s == "desc" ? "desc" : "asc"
      @page = [ page.to_i, 1 ].max
      @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
    end

    def call
      ordered = @sort ? sort_explicit(filtered_candidates) : sort_default(filtered_candidates)

      Result.new(
        entries: hydrate(paginate(ordered)),
        total: ordered.size,
        page: @page,
        per_page: @per_page
      )
    end

    private

    def filtered_candidates
      case @bucket
      when Trajectory::CHRONIC, Trajectory::RECOVERING
        classified_established.filter_map { |ul, t| [ ul, Coverage::ESTABLISHED ] if t == @bucket }
      when Trajectory::STALLED
        classified_developing.filter_map { |ul, t| [ ul, Coverage::DEVELOPING ] if t == @bucket }
      when Trajectory::STABLE
        established = classified_established.filter_map { |ul, t| [ ul, Coverage::ESTABLISHED ] if t == Trajectory::STABLE }
        developing  = classified_developing.filter_map  { |ul, t| [ ul, Coverage::DEVELOPING ]  if t == Trajectory::STABLE }
        established + developing
      else
        raise ArgumentError, "unknown trajectory bucket: #{@bucket.inspect}"
      end
    end

    def classified_established
      @classified_established ||= established_records.map do |ul|
        [ ul, Trajectory.call(user_learning: ul, coverage: Coverage::ESTABLISHED, recent_eases: []) ]
      end
    end

    def classified_developing
      @classified_developing ||= developing_records.map do |ul|
        [ ul, Trajectory.call(user_learning: ul, coverage: Coverage::DEVELOPING, recent_eases: recent_eases[ul.id] || []) ]
      end
    end

    def established_records
      @established_records ||= @user.user_learnings
        .where.not(first_mastered_at: nil)
        .select(:id, :state, :graduation_count, :factor, :first_mastered_at, :next_due)
        .to_a
    end

    def developing_ids
      @developing_ids ||= @user.user_learnings
        .where(first_mastered_at: nil)
        .where.not(developing_at: nil)
        .pluck(:id)
    end

    def developing_records
      @developing_records ||= @user.user_learnings
        .where(id: developing_ids)
        .select(:id, :state, :graduation_count, :factor, :developing_at, :next_due)
        .to_a
    end

    def recent_eases
      @recent_eases ||= RecentEases.call(user_learning_ids: developing_ids)
    end

    def recent_average_ease(user_learning_id)
      eases = recent_eases[user_learning_id]
      return Float::INFINITY if eases.blank?

      eases.sum.to_f / eases.size
    end

    def since_for(user_learning, coverage)
      coverage == Coverage::ESTABLISHED ? user_learning.first_mastered_at : user_learning.developing_at
    end

    def sort_default(candidates)
      case @bucket
      when Trajectory::CHRONIC
        candidates.sort_by { |ul, _coverage| -ul.graduation_count }
      when Trajectory::RECOVERING
        candidates.sort_by { |ul, _coverage| -ul.factor }
      when Trajectory::STALLED
        candidates.sort_by { |ul, _coverage| recent_average_ease(ul.id) }
      when Trajectory::STABLE
        candidates.sort_by { |ul, coverage| [ coverage == Coverage::ESTABLISHED ? 0 : 1, -ul.factor ] }
      else
        candidates
      end
    end

    def sort_explicit(candidates)
      raise ArgumentError, "unsupported sort column: #{@sort.inspect}" unless SORTABLE_COLUMNS.include?(@sort)

      sorted = case @sort
      when "word"
        lookup = word_lookup(candidates.map { |ul, _coverage| ul.id })
        candidates.sort_by { |ul, _coverage| lookup.fetch(ul.id, "") }
      when "meaning"
        lookup = meaning_lookup(candidates.map { |ul, _coverage| ul.id })
        candidates.sort_by { |ul, _coverage| lookup.fetch(ul.id, "").to_s }
      when "ease"
        candidates.sort_by { |ul, _coverage| ul.factor }
      when "graduations"
        candidates.sort_by { |ul, _coverage| ul.graduation_count }
      when "since"
        candidates.sort_by { |ul, coverage| since_for(ul, coverage) || Time.at(0) }
      when "next_due"
        candidates.sort_by { |ul, _coverage| ul.next_due || Time.at(0) }
      end

      @direction == "desc" ? sorted.reverse : sorted
    end

    # Text only, no association hydration -- used purely to rank the whole
    # bucket by word when that's the explicit sort. dictionary_entry
    # itself is still only ever loaded for the final page, in #hydrate.
    def word_lookup(ids)
      return {} if ids.empty?

      @user.user_learnings.where(id: ids).joins(:dictionary_entry).pluck(:id, "dictionary_entries.text").to_h
    end

    # Mirrors what `dictionary_entry.meanings.first` returns elsewhere in
    # the app (Rails adds an implicit `ORDER BY id ASC` to an unscoped
    # `#first`) -- the lowest-id meaning per entry, fetched in one query
    # rather than N+1ing meanings per candidate.
    def meaning_lookup(ids)
      return {} if ids.empty?

      sql = Meaning.sanitize_sql_array([ <<~SQL, ids ])
        SELECT ul.id AS user_learning_id, m.text AS meaning_text
        FROM user_learnings ul
        JOIN meanings m ON m.id = (
          SELECT MIN(m2.id) FROM meanings m2 WHERE m2.dictionary_entry_id = ul.dictionary_entry_id
        )
        WHERE ul.id IN (?)
      SQL

      Meaning.connection.select_all(sql).each_with_object({}) do |row, memo|
        memo[row["user_learning_id"]] = row["meaning_text"]
      end
    end

    def paginate(candidates)
      offset = (@page - 1) * @per_page
      candidates[offset, @per_page] || []
    end

    # One rich fetch for exactly the current page's ids, regardless of how
    # many the bucket holds -- both query count and data volume stay fixed
    # as bucket size grows. `where(id:)` doesn't preserve the order of
    # `ids`, so results are re-keyed and walked back out in the order
    # already decided by sort_default/sort_explicit above.
    def hydrate(page_candidates)
      return [] if page_candidates.empty?

      coverage_by_id = page_candidates.to_h { |ul, coverage| [ ul.id, coverage ] }
      ordered_ids = page_candidates.map { |ul, _coverage| ul.id }

      records_by_id = @user.user_learnings
        .where(id: ordered_ids)
        .includes(dictionary_entry: :meanings)
        .index_by(&:id)

      ordered_ids.map do |id|
        ul      = records_by_id.fetch(id)
        entry   = ul.dictionary_entry
        # entry.meanings is already an in-memory Array here (preloaded via
        # .includes above), so plain #first would return whichever row the
        # preload query happened to return first -- has_many :meanings has
        # no explicit order, so that's unspecified, unlike a fresh
        # Relation#first (which Rails gives an implicit ORDER BY id).
        # #min_by(&:id) makes the choice deterministic and matches
        # meaning_lookup's explicit MIN(id) above.
        meaning = entry.meanings.min_by(&:id)
        coverage = coverage_by_id.fetch(id)

        Entry.new(
          id: ul.id,
          text: entry.text,
          pinyin: meaning&.pinyin,
          meaning: meaning&.text,
          coverage: coverage,
          factor: ul.factor,
          graduation_count: ul.graduation_count,
          since: since_for(ul, coverage),
          next_due: ul.next_due
        )
      end
    end
  end
end
