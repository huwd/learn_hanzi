require 'rails_helper'

RSpec.describe LearningSession::Composer do
  let(:user) { create(:user) }

  describe ".call" do
    subject(:queue) { described_class.call(user: user, size: size, new_cap: new_cap) }

    let(:size) { 10 }
    let(:new_cap) { 3 }

    context "when the user has no cards" do
      it "returns an empty array" do
        expect(queue).to be_empty
      end
    end

    context "when the user has only new cards" do
      before { create_list(:user_learning, 5, user: user, state: "new") }

      it "returns new cards up to new_cap" do
        expect(queue.size).to eq(3)
      end

      it "returns UserLearning records" do
        expect(queue).to all(be_a(UserLearning))
      end

      it "orders new cards by created_at ascending (oldest first)" do
        expect(queue.map(&:created_at)).to eq(queue.map(&:created_at).sort)
      end
    end

    context "when the user has more new cards than the session size" do
      before { create_list(:user_learning, 15, user: user, state: "new") }

      it "does not exceed session size even with fallback fill" do
        expect(queue.size).to eq(size)
      end
    end

    context "when the user has overdue learning cards" do
      before do
        create_list(:user_learning, 4, user: user, state: "learning",
                    next_due: 2.days.ago, last_interval: 1)
      end

      it "includes all overdue learning cards" do
        expect(queue.size).to eq(4)
        expect(queue.map(&:state)).to all(eq("learning"))
      end
    end

    context "when overdue learning cards fill the session" do
      before do
        create_list(:user_learning, 12, user: user, state: "learning",
                    next_due: 2.days.ago, last_interval: 1)
        create_list(:user_learning, 3, user: user, state: "new")
      end

      it "does not exceed session size" do
        expect(queue.size).to eq(size)
      end

      it "prioritises learning cards over new cards" do
        expect(queue.map(&:state)).to all(eq("learning"))
      end
    end

    context "priority ordering: overdue learning before new before due mastered" do
      let!(:new_card) { create(:user_learning, user: user, state: "new") }
      let!(:learning_card) do
        create(:user_learning, user: user, state: "learning",
               next_due: 1.day.ago, last_interval: 1)
      end
      let!(:mastered_card) do
        create(:user_learning, user: user, state: "mastered",
               next_due: 1.day.ago, last_interval: 10)
      end
      let!(:future_mastered) do
        create(:user_learning, user: user, state: "mastered",
               next_due: 7.days.from_now, last_interval: 10)
      end

      it "puts overdue learning first" do
        expect(queue.first).to eq(learning_card)
      end

      it "includes new cards second" do
        expect(queue).to include(new_card)
      end

      it "includes due mastered cards" do
        expect(queue).to include(mastered_card)
      end

      it "excludes mastered cards not yet due" do
        expect(queue).not_to include(future_mastered)
      end
    end

    context "new card cap enforcement" do
      before do
        create_list(:user_learning, 6, user: user, state: "new")
      end

      it "limits new cards to new_cap initially" do
        # With no other cards, fallback fill kicks in, so we need overdue cards to test cap
        learning_cards = create_list(:user_learning, 5, user: user, state: "learning",
                                     next_due: 1.day.ago, last_interval: 1)
        result = described_class.call(user: user, size: 10, new_cap: 2)
        new_in_queue = result.count { |ul| ul.state == "new" }
        expect(new_in_queue).to eq(2)
      end
    end

    context "fallback fill with additional new cards" do
      before do
        # Only 2 overdue learning, 6 new, no mastered due
        create_list(:user_learning, 2, user: user, state: "learning",
                    next_due: 1.day.ago, last_interval: 1)
        create_list(:user_learning, 6, user: user, state: "new")
      end

      it "fills remaining slots beyond new_cap with additional new cards" do
        # size=10, new_cap=3: 2 learning + 3 new = 5, then 5 more from remaining new
        expect(queue.size).to eq(8) # 2 learning + 6 new (no mastered to fill with)
      end

      it "does not duplicate cards" do
        expect(queue.map(&:id).uniq.size).to eq(queue.size)
      end
    end

    context "not-yet-due learning and mastered cards" do
      before do
        create(:user_learning, user: user, state: "learning",
               next_due: 3.days.from_now, last_interval: 1)
        create(:user_learning, user: user, state: "mastered",
               next_due: 7.days.from_now, last_interval: 20)
      end

      it "excludes cards that are not yet due" do
        expect(queue).to be_empty
      end
    end
  end
end
