require 'rails_helper'

RSpec.describe UserLearning::Enqueue do
  let(:user) { create(:user) }

  describe ".call" do
    context "with no tag" do
      it "creates no records" do
        expect { described_class.call(user: user) }.not_to change(UserLearning, :count)
      end
    end

    context "with a tag" do
      let(:tag)   { create(:tag, name: "HSK 4") }
      let(:child) { create(:tag, name: "Lesson 1", parent: tag) }
      let!(:entry_a) { create(:dictionary_entry).tap { |e| e.tags << tag } }
      let!(:entry_b) { create(:dictionary_entry).tap { |e| e.tags << child } }
      let!(:unrelated) { create(:dictionary_entry).tap { |e| e.tags << create(:tag, name: "HSK 2") } }

      it "creates UserLearning records for entries with no existing record" do
        expect { described_class.call(user: user, tag: tag) }
          .to change(UserLearning, :count).by(2)
      end

      it "creates records with state: new" do
        described_class.call(user: user, tag: tag)
        expect(user.user_learnings.pluck(:state)).to all(eq("new"))
      end

      it "scopes new records to the calling user" do
        described_class.call(user: user, tag: tag)
        expect(UserLearning.last(2).map(&:user_id)).to all(eq(user.id))
      end

      it "includes entries from descendant tags" do
        described_class.call(user: user, tag: tag)
        created_entry_ids = user.user_learnings.pluck(:dictionary_entry_id)
        expect(created_entry_ids).to include(entry_b.id)
      end

      it "does not create records for entries outside the tag subtree" do
        described_class.call(user: user, tag: tag)
        created_entry_ids = user.user_learnings.pluck(:dictionary_entry_id)
        expect(created_entry_ids).not_to include(unrelated.id)
      end

      it "is idempotent — does not create duplicates on repeated calls" do
        described_class.call(user: user, tag: tag)
        expect { described_class.call(user: user, tag: tag) }.not_to change(UserLearning, :count)
      end

      context "when the user already has a record for some entries" do
        before { create(:user_learning, user: user, dictionary_entry: entry_a, state: "learning") }

        it "only creates records for the missing entries" do
          expect { described_class.call(user: user, tag: tag) }
            .to change(UserLearning, :count).by(1)
        end
      end
    end
  end
end
