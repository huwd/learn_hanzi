class AddSourceToMeanings < ActiveRecord::Migration[8.0]
  def change
    add_reference :meanings, :source, foreign_key: true
  end
end
