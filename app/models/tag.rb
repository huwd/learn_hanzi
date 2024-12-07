class Tag < ApplicationRecord
  has_many :dictionary_entry_tags, dependent: :destroy
  has_many :dictionary_entries, through: :dictionary_entry_tags

  belongs_to :parent, class_name: "Tag", optional: true
  has_many :children, class_name: "Tag", foreign_key: "parent_id", dependent: :destroy

  validates :name, presence: true
end
