class AddUniqueIndexToTags < ActiveRecord::Migration[8.0]
  def change
    add_index :tags, [ :parent_id, :id ], unique: true, name: 'index_tags_on_parent_and_child'
  end
end
