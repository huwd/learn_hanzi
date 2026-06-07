class LearningSession::Composer
    DEFAULT_SIZE = 20
    DEFAULT_NEW_CAP = 5

    HSK_LEVEL_NAMES = [ "HSK 1", "HSK 2", "HSK 3", "HSK 4", "HSK 5", "HSK 6", "HSK 7-9" ].freeze

    def self.call(user:, size: DEFAULT_SIZE, new_cap: DEFAULT_NEW_CAP, include_new: false, tag: nil)
      new(user, size, new_cap, include_new, tag).call
    end

    def initialize(user, size, new_cap, include_new, tag = nil)
      @user = user
      @size = size
      @new_cap = new_cap
      @include_new = include_new
      @tag = tag
    end

    def call
      queue = []

      # Priority 1: all overdue learning cards
      queue.concat(overdue_learning_cards)
      return queue.first(@size) if queue.size >= @size

      # Priority 2: new cards, suppressed proportionally as the overdue backlog grows
      if @include_new
        effective_cap = (@new_cap * [ 1 - (queue.size / @size.to_f), 0 ].max).floor
        new_limit = [ @size - queue.size, effective_cap ].min
        queue.concat(new_cards(new_limit)) if effective_cap > 0
        return queue if queue.size >= @size
      end

      # Priority 3: due mastered cards (spot checks)
      needed = @size - queue.size
      queue.concat(due_mastered_cards.first(needed))

      queue
    end

    private

    def overdue_learning_cards
      scoped_learnings.overdue_learning.order(:next_due).to_a
    end

    def new_cards(limit)
      ul      = UserLearning.arel_table
      hsk_de  = Arel::Table.new("dictionary_entries", as: "hsk_de")
      hsk_det = Arel::Table.new("dictionary_entry_tags", as: "hsk_det")
      hsk_t   = Arel::Table.new("tags", as: "hsk_t")

      hsk_joins = [
        ul.join(hsk_de, Arel::Nodes::OuterJoin)
          .on(hsk_de[:id].eq(ul[:dictionary_entry_id]))
          .join_sources,
        ul.join(hsk_det, Arel::Nodes::OuterJoin)
          .on(hsk_det[:dictionary_entry_id].eq(hsk_de[:id]))
          .join_sources,
        ul.join(hsk_t, Arel::Nodes::OuterJoin)
          .on(
            hsk_t[:id].eq(hsk_det[:tag_id])
              .and(hsk_t[:category].eq("HSK"))
              .and(hsk_t[:name].in(HSK_LEVEL_NAMES))
          )
          .join_sources
      ].flatten

      scoped_learnings
        .new_learnings
        .joins(hsk_joins)
        .group("user_learnings.id")
        .order(Arel.sql("CASE WHEN MIN(hsk_t.id) IS NULL THEN 1 ELSE 0 END"))
        .order(Arel.sql("MIN(CAST(SUBSTR(hsk_t.name, 5) AS INTEGER))"))
        .order(Arel.sql("CASE WHEN hsk_de.frequency_rank IS NULL THEN 1 ELSE 0 END"))
        .order(Arel.sql("hsk_de.frequency_rank ASC"))
        .limit(limit)
        .to_a
    end

    def due_mastered_cards
      scoped_learnings.due_mastered.order(:next_due)
    end

    def scoped_learnings
      @scoped_learnings ||= if @tag
        entry_ids = DictionaryEntry
          .joins(:dictionary_entry_tags)
          .where(dictionary_entry_tags: { tag_id: @tag.subtree_ids })
          .select(:id)
        @user.user_learnings.where(dictionary_entry_id: entry_ids)
      else
        @user.user_learnings
      end
    end
end
