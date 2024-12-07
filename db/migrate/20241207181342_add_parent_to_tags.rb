class AddParentToTags < ActiveRecord::Migration[8.0]
  def change
    add_reference :tags, :parent, foreign_key: { to_table: :tags }
  end
end
