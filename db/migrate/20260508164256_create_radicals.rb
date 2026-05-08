class CreateRadicals < ActiveRecord::Migration[8.1]
  def change
    create_table :radicals do |t|
      t.string :character, null: false
      t.string :meaning
      t.integer :stroke_count

      t.timestamps
    end

    add_index :radicals, :character, unique: true
  end
end
