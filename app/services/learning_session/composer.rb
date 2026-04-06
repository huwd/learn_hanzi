class LearningSession::Composer
    DEFAULT_SIZE = 20
    DEFAULT_NEW_CAP = 5

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

      # Priority 2: new cards, capped to avoid flooding (only when explicitly requested)
      if @include_new
        new_limit = [ @size - queue.size, @new_cap ].min
        queue.concat(new_cards(new_limit))
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
      scoped_learnings.new_learnings.order(:created_at).limit(limit).to_a
    end

    def due_mastered_cards
      scoped_learnings.due_mastered.order(:next_due)
    end

    def scoped_learnings
      @scoped_learnings ||= if @tag
        @user.user_learnings
             .joins(dictionary_entry: :dictionary_entry_tags)
             .where(dictionary_entry_tags: { tag_id: @tag.subtree_ids })
             .distinct
      else
        @user.user_learnings
      end
    end
end
