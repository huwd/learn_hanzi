class AddPriorityToSources < ActiveRecord::Migration[8.1]
  def change
    add_column :sources, :priority, :integer, default: 100, null: false
  end
end
