class NullifyMasteredAtForLapsedUserLearnings < ActiveRecord::Migration[8.1]
  def up
    # Cards that lapsed before this fix was deployed have mastered_at set but
    # state != 'mastered'. Clear the timestamp so they are excluded from the
    # mastered count in the progress chart.
    UserLearning.where.not(state: "mastered").where.not(mastered_at: nil)
                .update_all(mastered_at: nil)
  end

  def down
    # mastered_at values cannot be recovered once cleared
    raise ActiveRecord::IrreversibleMigration
  end
end
