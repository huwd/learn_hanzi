module LearningSession
  class Composer
    DEFAULT_SIZE = 20
    DEFAULT_NEW_CAP = 5

    def self.call(user:, size: DEFAULT_SIZE, new_cap: DEFAULT_NEW_CAP)
      new(user, size, new_cap).call
    end

    def initialize(user, size, new_cap)
      @user = user
      @size = size
      @new_cap = new_cap
    end

    def call
      queue = []
      remaining_new = all_new_cards

      # Priority 1: all overdue learning cards
      queue.concat(overdue_learning_cards)
      return queue.first(@size) if queue.size >= @size

      # Priority 2: new cards, capped to avoid flooding
      new_limit = [ @size - queue.size, @new_cap ].min
      queue.concat(remaining_new.shift(new_limit))
      return queue if queue.size >= @size

      # Priority 3: due mastered cards (spot checks)
      needed = @size - queue.size
      queue.concat(due_mastered_cards.first(needed))
      return queue if queue.size >= @size

      # Fallback: fill remaining slots with additional new cards
      needed = @size - queue.size
      queue.concat(remaining_new.first(needed))

      queue
    end

    private

    def overdue_learning_cards
      @user.user_learnings.overdue_learning.order(:next_due).to_a
    end

    def all_new_cards
      @user.user_learnings.new_learnings.order(:created_at).to_a
    end

    def due_mastered_cards
      @user.user_learnings.due_mastered.order(:next_due)
    end
  end
end
