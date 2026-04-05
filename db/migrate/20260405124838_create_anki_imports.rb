class CreateAnkiImports < ActiveRecord::Migration[8.0]
  def change
    create_table :anki_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :state,                null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.integer  :cards_imported,       default: 0
      t.integer  :review_logs_imported, default: 0
      t.text     :error_message
      t.timestamps
    end

    add_index :anki_imports, [ :user_id, :created_at ]
  end
end
