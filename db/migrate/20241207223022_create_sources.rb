class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.string :name
      t.string :url
      t.date :date_accessed

      t.timestamps
    end
  end
end
