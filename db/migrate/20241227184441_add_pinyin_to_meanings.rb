class AddPinyinToMeanings < ActiveRecord::Migration[8.0]
  def up
    add_column :meanings, :pinyin, :string
  end

  def down
    remove_column :meanings, :pinyin
  end
end
