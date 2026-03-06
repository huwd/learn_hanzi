class AddUniqueIndexToReviewLogsAnkiId < ActiveRecord::Migration[8.1]
  def change
    add_index :review_logs, :anki_id, unique: true
  end
end
