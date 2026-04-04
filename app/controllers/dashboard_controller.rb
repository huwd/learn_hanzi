class DashboardController < ApplicationController
  def index
    user_learnings = Current.user.user_learnings

    @cards_due = user_learnings.overdue_learning.count +
                 user_learnings.due_mastered.count

    @state_counts = {
      new:       user_learnings.new_learnings.count,
      learning:  user_learnings.in_progress.count,
      mastered:  user_learnings.mastered.count
    }

    @new_cards_count = user_learnings.new_learnings.count

    @root_tags = Tag.where(parent_id: nil).order(:name)
  end
end
