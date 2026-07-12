require 'rails_helper'

RSpec.describe ReviewLog, type: :model do
  describe 'associations' do
    it { should belong_to(:user_learning) }
  end

  describe 'validations' do
    it { should validate_presence_of(:ease) }
    it { should validate_inclusion_of(:ease).in_range(1..4) }
  end

  describe 'data consistency' do
    it "ensures ease values are within the expected range" do
      log = build(:review_log, ease: 5)
      expect(log).not_to be_valid
      expect(log.errors[:ease]).to include("is not included in the list")
    end
  end

  describe 'developing_at' do
    let(:threshold) { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT }
    let(:user_learning) { create(:user_learning, user: create(:user), state: "learning") }

    it "sets developing_at on the user_learning at the threshold-th review" do
      (threshold - 1).times { create(:review_log, user_learning: user_learning, ease: 1) }

      expect { create(:review_log, user_learning: user_learning, ease: 1) }
        .to change { user_learning.reload.developing_at }.from(nil)
    end

    it "does not set developing_at before the threshold is reached" do
      (threshold - 2).times { create(:review_log, user_learning: user_learning, ease: 1) }

      expect { create(:review_log, user_learning: user_learning, ease: 1) }
        .not_to change { user_learning.reload.developing_at }
    end

    it "does not set developing_at once the word has graduated" do
      # ReviewController#submit updates user_learning's state before
      # creating the ReviewLog, so by the time this callback fires,
      # first_mastered_at already reflects the current review's outcome.
      (threshold - 1).times { create(:review_log, user_learning: user_learning, ease: 1) }
      user_learning.update!(state: "mastered", first_mastered_at: Time.current, mastered_at: Time.current)

      expect { create(:review_log, user_learning: user_learning, ease: 3) }
        .not_to change { user_learning.reload.developing_at }
    end

    it "does not change developing_at once already set" do
      (threshold - 1).times { create(:review_log, user_learning: user_learning, ease: 1) }
      create(:review_log, user_learning: user_learning, ease: 1)
      original = user_learning.reload.developing_at

      expect { create(:review_log, user_learning: user_learning, ease: 1) }
        .not_to change { user_learning.reload.developing_at }
      expect(user_learning.reload.developing_at).to eq(original)
    end
  end
end
