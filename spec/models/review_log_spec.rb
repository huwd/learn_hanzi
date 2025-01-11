require 'rails_helper'

RSpec.describe ReviewLog, type: :model do
  describe 'associations' do
    it { should belong_to(:user_learning) }
  end

  describe 'validations' do
    it { should validate_presence_of(:ease) }
    it { should validate_inclusion_of(:ease).in_range(1..4) }
    it { should validate_presence_of(:reviewed_at) }
  end

  describe 'data consistency' do
    it "ensures ease values are within the expected range" do
      log = build(:review_log, ease: 5)
      expect(log).not_to be_valid
      expect(log.errors[:ease]).to include("is not included in the list")
    end
  end
end
