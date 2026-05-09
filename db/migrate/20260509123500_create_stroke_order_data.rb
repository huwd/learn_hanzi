class CreateStrokeOrderData < ActiveRecord::Migration[8.1]
  def change
    create_table :stroke_order_data do |t|
      t.references :dictionary_entry, null: false, foreign_key: true, index: { unique: true }
      t.text :strokes, null: false
      t.text :medians, null: false
      t.string :source, null: false
      t.timestamps
    end
  end
end
