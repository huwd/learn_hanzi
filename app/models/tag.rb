class Tag < ApplicationRecord
  has_many :dictionary_entry_tags, dependent: :destroy
  has_many :dictionary_entries, through: :dictionary_entry_tags

  belongs_to :parent, class_name: "Tag", optional: true
  has_many :children, class_name: "Tag", foreign_key: "parent_id", dependent: :destroy

  validates :name, presence: true

  def subtree_ids
    [ id ] + children.flat_map(&:subtree_ids)
  end

  def ancestors
    chain = []
    node = parent
    while node
      chain.unshift(node)
      node = node.parent
    end
    chain
  end

  def add_child(child_tag)
    children << child_tag unless children.exists?(child_tag.id)
  end
end
