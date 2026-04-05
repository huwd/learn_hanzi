require 'rails_helper'

RSpec.describe AnkiImport, type: :model do
  let(:user) { create(:user) }

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_inclusion_of(:state).in_array(%w[pending running complete failed]) }
  end

  describe "state predicates" do
    %w[pending running complete failed].each do |state|
      it "returns true for ##{state}? when state is #{state}" do
        import = build(:anki_import, user: user, state: state)
        expect(import.public_send(:"#{state}?")).to be true
      end

      it "returns false for ##{state}? when state is not #{state}" do
        other_state = (%w[pending running complete failed] - [state]).first
        import = build(:anki_import, user: user, state: other_state)
        expect(import.public_send(:"#{state}?")).to be false
      end
    end
  end

  describe ".recent scope" do
    it "orders by created_at descending" do
      older = create(:anki_import, user: user, created_at: 2.hours.ago)
      newer = create(:anki_import, user: user, created_at: 1.hour.ago)
      expect(AnkiImport.recent.first).to eq(newer)
      expect(AnkiImport.recent.last).to eq(older)
    end
  end
end
