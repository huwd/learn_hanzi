class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :category

      t.timestamps
    end

    add_index :tags, :name
  end
end
