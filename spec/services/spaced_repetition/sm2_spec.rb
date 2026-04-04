require 'rails_helper'

RSpec.describe SpacedRepetition::SM2 do
  def user_learning(state: "new", last_interval: 1, factor: 2500)
    instance_double(UserLearning, state: state, last_interval: last_interval, factor: factor)
  end

  describe ".call" do
    subject(:result) { described_class.call(user_learning: ul, ease: ease) }

    context "when ease is 1 (Again)" do
      let(:ease) { 1 }

      context "with a new card" do
        let(:ul) { user_learning(state: "new", last_interval: 1, factor: 2500) }

        it "sets interval to 1" do
          expect(result.interval).to eq(1)
        end

        it "reduces factor by 200" do
          expect(result.factor).to eq(2300)
        end

        it "advances state to learning" do
          expect(result.new_state).to eq("learning")
        end

        it "sets next_due to 1 day from now" do
          expect(result.next_due).to be_within(5.seconds).of(1.day.from_now)
        end
      end

      context "with a learning card" do
        let(:ul) { user_learning(state: "learning", last_interval: 3, factor: 2500) }

        it "resets interval to 1" do
          expect(result.interval).to eq(1)
        end

        it "keeps state as learning" do
          expect(result.new_state).to eq("learning")
        end

        it "reduces factor, floored at MIN_FACTOR" do
          expect(result.factor).to eq(2300)
        end
      end

      context "with a mastered card (lapse)" do
        let(:ul) { user_learning(state: "mastered", last_interval: 30, factor: 2500) }

        it "resets interval to 1" do
          expect(result.interval).to eq(1)
        end

        it "reverts state to learning" do
          expect(result.new_state).to eq("learning")
        end
      end

      context "when factor is already at minimum" do
        let(:ul) { user_learning(state: "learning", last_interval: 1, factor: 1300) }

        it "does not drop factor below MIN_FACTOR" do
          expect(result.factor).to eq(1300)
        end
      end
    end

    context "when ease is 2 (Hard)" do
      let(:ease) { 2 }

      context "with a new card" do
        let(:ul) { user_learning(state: "new", last_interval: 1, factor: 2500) }

        it "sets interval to at least 1" do
          expect(result.interval).to be >= 1
        end

        it "reduces factor by 150" do
          expect(result.factor).to eq(2350)
        end

        it "advances state to learning" do
          expect(result.new_state).to eq("learning")
        end
      end

      context "with a learning card" do
        let(:ul) { user_learning(state: "learning", last_interval: 5, factor: 2500) }

        it "increases interval by 1.2x" do
          expect(result.interval).to eq(6)
        end

        it "keeps state as learning" do
          expect(result.new_state).to eq("learning")
        end
      end

      context "with a mastered card" do
        let(:ul) { user_learning(state: "mastered", last_interval: 10, factor: 2500) }

        it "keeps state as mastered" do
          expect(result.new_state).to eq("mastered")
        end
      end

      context "when factor is already at minimum" do
        let(:ul) { user_learning(state: "learning", last_interval: 2, factor: 1300) }

        it "does not drop factor below MIN_FACTOR" do
          expect(result.factor).to eq(1300)
        end
      end
    end

    context "when ease is 3 (Good)" do
      let(:ease) { 3 }

      context "with a new card" do
        let(:ul) { user_learning(state: "new", last_interval: 1, factor: 2500) }

        it "calculates interval using factor" do
          # ceil(1 * 2500 / 1000) = 3
          expect(result.interval).to eq(3)
        end

        it "does not change factor" do
          expect(result.factor).to eq(2500)
        end

        it "advances state to learning" do
          expect(result.new_state).to eq("learning")
        end
      end

      context "with a learning card" do
        let(:ul) { user_learning(state: "learning", last_interval: 3, factor: 2500) }

        it "calculates interval using factor" do
          # ceil(3 * 2500 / 1000) = 8
          expect(result.interval).to eq(8)
        end

        it "graduates state to mastered" do
          expect(result.new_state).to eq("mastered")
        end
      end

      context "with a mastered card" do
        let(:ul) { user_learning(state: "mastered", last_interval: 10, factor: 2500) }

        it "keeps state as mastered" do
          expect(result.new_state).to eq("mastered")
        end

        it "extends interval" do
          # ceil(10 * 2500 / 1000) = 25
          expect(result.interval).to eq(25)
        end
      end

      context "when interval would round below 1" do
        let(:ul) { user_learning(state: "new", last_interval: 0, factor: 100) }

        it "floors interval at 1" do
          expect(result.interval).to eq(1)
        end
      end
    end

    context "when ease is 4 (Easy)" do
      let(:ease) { 4 }

      context "with a new card" do
        let(:ul) { user_learning(state: "new", last_interval: 1, factor: 2500) }

        it "applies easy bonus to interval" do
          # ceil(1 * 2500 / 1000 * 1.3) = ceil(3.25) = 4
          expect(result.interval).to eq(4)
        end

        it "increases factor by 150" do
          expect(result.factor).to eq(2650)
        end

        it "advances state to learning" do
          expect(result.new_state).to eq("learning")
        end
      end

      context "with a learning card" do
        let(:ul) { user_learning(state: "learning", last_interval: 3, factor: 2500) }

        it "graduates state to mastered" do
          expect(result.new_state).to eq("mastered")
        end

        it "applies easy bonus" do
          # ceil(3 * 2500 / 1000 * 1.3) = ceil(9.75) = 10
          expect(result.interval).to eq(10)
        end
      end

      context "with a mastered card" do
        let(:ul) { user_learning(state: "mastered", last_interval: 10, factor: 2500) }

        it "keeps state as mastered" do
          expect(result.new_state).to eq("mastered")
        end
      end
    end

    context "when factor is nil (unset)" do
      let(:ease) { 3 }
      let(:ul) { user_learning(state: "new", last_interval: 1, factor: nil) }

      it "defaults to DEFAULT_FACTOR" do
        # ceil(1 * 2500 / 1000) = 3
        expect(result.interval).to eq(3)
      end
    end

    context "when last_interval is nil (first review)" do
      let(:ease) { 3 }
      let(:ul) { user_learning(state: "new", last_interval: nil, factor: 2500) }

      it "treats last_interval as 1" do
        expect(result.interval).to eq(3)
      end
    end
  end
end
