require 'rails_helper'

RSpec.describe Mastery::Coverage do
  def user_learning(state: "new", first_mastered_at: nil)
    instance_double(UserLearning, state: state, first_mastered_at: first_mastered_at)
  end

  describe ".call" do
    subject(:coverage) { described_class.call(user_learning: ul, review_count: review_count) }

    context "when suspended, regardless of review count or history" do
      let(:ul) { user_learning(state: "suspended", first_mastered_at: 2.days.ago) }
      let(:review_count) { 10 }

      it { is_expected.to eq(Mastery::Coverage::SUSPENDED) }
    end

    context "with zero reviews" do
      let(:ul) { user_learning(state: "new") }
      let(:review_count) { 0 }

      it { is_expected.to eq(Mastery::Coverage::UNSEEN) }
    end

    context "when first_mastered_at is present" do
      let(:ul) { user_learning(state: "learning", first_mastered_at: 5.days.ago) }
      let(:review_count) { 20 }

      it "is Established even though it has since lapsed" do
        expect(coverage).to eq(Mastery::Coverage::ESTABLISHED)
      end
    end

    context "when never graduated and below the threshold" do
      let(:ul) { user_learning(state: "learning") }
      let(:review_count) { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT - 1 }

      it { is_expected.to eq(Mastery::Coverage::EMERGING) }
    end

    context "when never graduated and at or above the threshold" do
      let(:ul) { user_learning(state: "learning") }
      let(:review_count) { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT }

      it { is_expected.to eq(Mastery::Coverage::DEVELOPING) }
    end
  end
end
