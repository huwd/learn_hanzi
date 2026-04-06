require 'rails_helper'

RSpec.describe LearningSessionCard, type: :model do
  subject { build(:learning_session_card) }

  describe "associations" do
    it { is_expected.to belong_to(:learning_session) }
    it { is_expected.to belong_to(:user_learning) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_inclusion_of(:ease).in_array([ 1, 2, 3, 4 ]).allow_nil }
  end
end
