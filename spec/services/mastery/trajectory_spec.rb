require 'rails_helper'

RSpec.describe Mastery::Trajectory do
  def user_learning(state: "learning", graduation_count: 0)
    instance_double(UserLearning, state: state, graduation_count: graduation_count)
  end

  describe ".call" do
    subject(:trajectory) do
      described_class.call(user_learning: ul, coverage: coverage, recent_eases: recent_eases)
    end

    let(:recent_eases) { [] }

    context "when coverage is Unseen, Emerging, or Suspended" do
      let(:ul) { user_learning }

      [ Mastery::Coverage::UNSEEN, Mastery::Coverage::EMERGING, Mastery::Coverage::SUSPENDED ].each do |ineligible|
        context "with coverage #{ineligible}" do
          let(:coverage) { ineligible }

          it { is_expected.to eq(Mastery::Trajectory::NOT_APPLICABLE) }
        end
      end
    end

    context "when graduated twice or more" do
      let(:ul) { user_learning(state: "mastered", graduation_count: 2) }
      let(:coverage) { Mastery::Coverage::ESTABLISHED }

      it { is_expected.to eq(Mastery::Trajectory::CHRONIC) }
    end

    context "when graduated once and currently lapsed" do
      let(:ul) { user_learning(state: "learning", graduation_count: 1) }
      let(:coverage) { Mastery::Coverage::ESTABLISHED }

      it { is_expected.to eq(Mastery::Trajectory::RECOVERING) }
    end

    context "when graduated once and still mastered" do
      let(:ul) { user_learning(state: "mastered", graduation_count: 1) }
      let(:coverage) { Mastery::Coverage::ESTABLISHED }

      it { is_expected.to eq(Mastery::Trajectory::STABLE) }
    end

    context "when never graduated with a flat/declining recent ease trend" do
      let(:ul) { user_learning(state: "learning", graduation_count: 0) }
      let(:coverage) { Mastery::Coverage::DEVELOPING }
      let(:recent_eases) { [ 1, 1, 1, 1, 1 ] }

      it { is_expected.to eq(Mastery::Trajectory::STALLED) }
    end

    context "when never graduated but recent eases are improving" do
      let(:ul) { user_learning(state: "learning", graduation_count: 0) }
      let(:coverage) { Mastery::Coverage::DEVELOPING }
      let(:recent_eases) { [ 1, 1, 3, 3, 4 ] }

      it { is_expected.to eq(Mastery::Trajectory::STABLE) }
    end

    context "when never graduated and no recent eases are supplied" do
      let(:ul) { user_learning(state: "learning", graduation_count: 0) }
      let(:coverage) { Mastery::Coverage::DEVELOPING }
      let(:recent_eases) { [] }

      it "does not misclassify as Stalled without data" do
        expect(trajectory).to eq(Mastery::Trajectory::STABLE)
      end
    end

    it "only looks at the last STALLED_LOOKBACK_REVIEWS eases" do
      ul = user_learning(state: "learning", graduation_count: 0)
      # An old bad streak followed by a recent improving run should not
      # count as stalled once enough recent reviews have gone well.
      eases = [ 1, 1, 1, 1, 1, 4, 4, 4 ]
      result = described_class.call(user_learning: ul, coverage: Mastery::Coverage::DEVELOPING, recent_eases: eases)
      expect(result).to eq(Mastery::Trajectory::STABLE)
    end
  end
end
