class AddSourceExportIdToReviewLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :review_logs, :source_export_id, :integer
    add_index :review_logs, [ :user_learning_id, :source_export_id ],
              unique: true,
              where: "source_export_id IS NOT NULL",
              name: "index_review_logs_on_ul_and_source_export_id"
  end
end
