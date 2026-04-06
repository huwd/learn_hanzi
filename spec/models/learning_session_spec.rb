require 'rails_helper'

RSpec.describe LearningSession, type: :model do
  subject(:ls) { build(:learning_session) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:learning_session_cards).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:started_at) }
    it { is_expected.to validate_inclusion_of(:state).in_array(%w[in_progress completed abandoned]) }
  end

  describe "#complete!" do
    let(:ls) { create(:learning_session, state: "in_progress") }

    it "marks the session as completed" do
      ls.complete!
      expect(ls.reload.state).to eq("completed")
    end

    it "sets completed_at" do
      ls.complete!
      expect(ls.reload.completed_at).to be_present
    end
  end

  describe "#current_card" do
    let(:ls) { create(:learning_session, state: "in_progress") }
    let(:ul1) { create(:user_learning, user: ls.user) }
    let(:ul2) { create(:user_learning, user: ls.user) }

    before do
      create(:learning_session_card, learning_session: ls, user_learning: ul1, position: 0)
      create(:learning_session_card, learning_session: ls, user_learning: ul2, position: 1)
    end

    it "returns the card at the given position" do
      expect(ls.current_card(0).user_learning).to eq(ul1)
      expect(ls.current_card(1).user_learning).to eq(ul2)
    end
  end

  describe "#reviewed_count" do
    let(:ls) { create(:learning_session) }

    before do
      create(:learning_session_card, learning_session: ls, reviewed_at: nil)
      create(:learning_session_card, learning_session: ls, reviewed_at: 1.minute.ago)
      create(:learning_session_card, learning_session: ls, reviewed_at: 2.minutes.ago)
    end

    it "counts only cards that have been reviewed" do
      expect(ls.reviewed_count).to eq(2)
    end
  end
end
