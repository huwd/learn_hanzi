class AddGraduationCountToUserLearnings < ActiveRecord::Migration[8.1]
  def change
    # Durable count of learning -> mastered crossings, incremented on every
    # such transition and never decremented. Lets Mastery::Trajectory
    # classify "Chronic" (>=2 crossings) without replaying full review
    # history per word on every request. See #391 and
    # app/services/mastery/README.md.
    add_column :user_learnings, :graduation_count, :integer, default: 0, null: false
  end
end
