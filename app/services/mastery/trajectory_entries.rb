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
  class TrajectoryEntries
    Entry = Data.define(:id, :text, :pinyin, :meaning, :coverage, :factor, :graduation_count, :since, :next_due)
    Result = Data.define(:entries, :total, :page, :per_page)

    PER_PAGE = 50

    SORT_KEYS = {
      "word"        => ->(entry) { entry.text },
      "meaning"     => ->(entry) { entry.meaning.to_s },
      "ease"        => ->(entry) { entry.factor },
      "graduations" => ->(entry) { entry.graduation_count },
      "since"       => ->(entry) { entry.since || Time.at(0) },
      "next_due"    => ->(entry) { entry.next_due || Time.at(0) }
    }.freeze

    SORTABLE_COLUMNS = SORT_KEYS.keys.freeze

    def self.call(user:, bucket:, sort: nil, direction: nil, page: 1, per_page: PER_PAGE)
      new(user, bucket, sort, direction, page, per_page).call
    end

    def initialize(user, bucket, sort, direction, page, per_page)
      @user = user
      @bucket = bucket
      @sort = sort
      @direction = direction.to_s == "desc" ? "desc" : "asc"
      @page = [ page.to_i, 1 ].max
      @per_page = [ per_page.to_i, 1 ].max
    end

    def call
      entries = hydrate(filtered_ids_with_coverage)
      ordered = @sort ? sort_explicit(entries) : sort_default(entries)

      Result.new(
        entries: paginate(ordered),
        total: ordered.size,
        page: @page,
        per_page: @per_page
      )
    end

    private

    def filtered_ids_with_coverage
      case @bucket
      when Trajectory::CHRONIC, Trajectory::RECOVERING
        classified_established.filter_map { |ul, t| [ ul.id, Coverage::ESTABLISHED ] if t == @bucket }
      when Trajectory::STALLED
        classified_developing.filter_map { |ul, t| [ ul.id, Coverage::DEVELOPING ] if t == @bucket }
      when Trajectory::STABLE
        established = classified_established.filter_map { |ul, t| [ ul.id, Coverage::ESTABLISHED ] if t == Trajectory::STABLE }
        developing  = classified_developing.filter_map  { |ul, t| [ ul.id, Coverage::DEVELOPING ]  if t == Trajectory::STABLE }
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
        .select(:id, :state, :graduation_count)
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
        .select(:id, :state, :graduation_count)
        .to_a
    end

    def recent_eases
      @recent_eases ||= RecentEases.call(user_learning_ids: developing_ids)
    end

    # One rich fetch for exactly the filtered ids, regardless of how many
    # the bucket holds -- query count stays fixed as bucket size grows,
    # same guarantee TrajectorySnapshot already gives.
    def hydrate(ids_with_coverage)
      coverage_by_id = ids_with_coverage.to_h
      return [] if coverage_by_id.empty?

      @user.user_learnings
        .where(id: coverage_by_id.keys)
        .includes(dictionary_entry: :meanings)
        .map do |ul|
          entry   = ul.dictionary_entry
          meaning = entry.meanings.first
          coverage = coverage_by_id.fetch(ul.id)

          Entry.new(
            id: ul.id,
            text: entry.text,
            pinyin: meaning&.pinyin,
            meaning: meaning&.text,
            coverage: coverage,
            factor: ul.factor,
            graduation_count: ul.graduation_count,
            since: coverage == Coverage::ESTABLISHED ? ul.first_mastered_at : ul.developing_at,
            next_due: ul.next_due
          )
        end
    end

    def sort_explicit(entries)
      raise ArgumentError, "unsupported sort column: #{@sort.inspect}" unless SORTABLE_COLUMNS.include?(@sort)

      key = SORT_KEYS.fetch(@sort)
      sorted = entries.sort_by { |entry| key.call(entry) }
      @direction == "desc" ? sorted.reverse : sorted
    end

    def sort_default(entries)
      case @bucket
      when Trajectory::CHRONIC
        entries.sort_by { |e| -e.graduation_count }
      when Trajectory::RECOVERING
        entries.sort_by { |e| -e.factor }
      when Trajectory::STALLED
        entries.sort_by { |e| recent_average_ease(e.id) }
      when Trajectory::STABLE
        entries.sort_by { |e| [ e.coverage == Coverage::ESTABLISHED ? 0 : 1, -e.factor ] }
      else
        entries
      end
    end

    def recent_average_ease(user_learning_id)
      eases = recent_eases[user_learning_id]
      return Float::INFINITY if eases.blank?

      eases.sum.to_f / eases.size
    end

    def paginate(entries)
      offset = (@page - 1) * @per_page
      entries[offset, @per_page] || []
    end
  end
end
