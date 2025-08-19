require 'rails_helper'

RSpec.describe Anki::Note, type: :model do
  describe ".find_by_character" do
    it "returns notes whose Simplified field matches the character" do
      notes = Anki::Note.find_by_character("好")
      expect(notes).to all(be_a(Anki::Note))
      expect(notes.map { |n| n.card_data["Simplified"] }).to include("好")
    end
  end
end
