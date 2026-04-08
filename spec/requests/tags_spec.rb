require 'rails_helper'

RSpec.describe "Tags", type: :request do
  let(:user)             { create(:user) }
  let(:root_tag)         { create(:tag, name: "HSK 2.0") }
  let(:mid_tag)          { create(:tag, name: "HSK 4", parent: root_tag) }
  let(:leaf_tag)         { create(:tag, name: "Lesson 1", parent: mid_tag) }
  let(:dictionary_entry) { create(:dictionary_entry) }

  before do
    root_tag.dictionary_entries << dictionary_entry
  end

  context "when authenticated" do
    before { sign_in user }

    describe "GET /tags" do
      before { mid_tag } # ensure hierarchy exists

      it "returns a successful response" do
        get tags_path
        expect(response).to have_http_status(:success)
      end

      it "links to root tags by name" do
        get tags_path
        expect(response.body).to include(root_tag.name)
      end

      it "shows the child count for root tags" do
        get tags_path
        expect(response.body).to include("1") # root_tag has one child (mid_tag)
      end
    end

    describe "GET /tags/:id (root tag)" do
      it "returns a successful response" do
        get tag_path(root_tag)
        expect(response).to have_http_status(:success)
      end

      it "renders the tag name as the heading" do
        get tag_path(root_tag)
        expect(response.body).to include("#{root_tag.name}</h1>")
      end

      it "does not render a breadcrumb for a root tag" do
        get tag_path(root_tag)
        expect(response.body).not_to include("breadcrumb")
      end
    end

    describe "GET /tags/:id — due indicator" do
      let(:due_entry) { create(:dictionary_entry).tap { |e| e.tags << root_tag } }

      context "when an entry is due for review" do
        before do
          create(:user_learning, user: user, dictionary_entry: due_entry,
                 state: "learning", next_due: 1.day.ago, last_interval: 1)
        end

        it "renders a due indicator for that tile" do
          get tag_path(root_tag)
          expect(response.body).to include("due-indicator")
        end
      end

      context "when an entry is not yet due" do
        before do
          create(:user_learning, user: user, dictionary_entry: due_entry,
                 state: "learning", next_due: 1.day.from_now, last_interval: 1)
        end

        it "does not render a due indicator" do
          get tag_path(root_tag)
          expect(response.body).not_to include("due-indicator")
        end
      end

      context "when an entry has no UserLearning" do
        it "does not render a due indicator" do
          get tag_path(root_tag)
          expect(response.body).not_to include("due-indicator")
        end
      end
    end

    describe "GET /tags/:id — due summary" do
      let(:entry) { create(:dictionary_entry).tap { |e| e.tags << mid_tag } }

      context "when overdue learning cards exist within the tag subtree" do
        before do
          create(:user_learning, user: user, dictionary_entry: entry,
                 state: "learning", next_due: 1.day.ago, last_interval: 1)
        end

        it "shows the review link scoped to that tag" do
          get tag_path(mid_tag)
          expect(response.body).to include(review_path(tag_id: mid_tag.id))
        end

        it "shows the in-progress count" do
          get tag_path(mid_tag)
          expect(response.body).to include("1 in progress")
        end
      end

      context "when a descendant tag has overdue cards" do
        let(:child_entry) { create(:dictionary_entry).tap { |e| e.tags << leaf_tag } }

        before do
          create(:user_learning, user: user, dictionary_entry: child_entry,
                 state: "learning", next_due: 1.day.ago, last_interval: 1)
        end

        it "shows the review link for the parent tag" do
          get tag_path(mid_tag)
          expect(response.body).to include(review_path(tag_id: mid_tag.id))
        end
      end

      context "when a mastered card is due for spot-check" do
        before do
          create(:user_learning, user: user, dictionary_entry: entry,
                 state: "mastered", next_due: 1.day.ago, last_interval: 30)
        end

        it "shows the review link" do
          get tag_path(mid_tag)
          expect(response.body).to include(review_path(tag_id: mid_tag.id))
        end

        it "shows the to-review count" do
          get tag_path(mid_tag)
          expect(response.body).to include("1 to review")
        end
      end

      context "when no overdue cards exist in the subtree" do
        before do
          create(:user_learning, user: user, dictionary_entry: entry,
                 state: "learning", next_due: 7.days.from_now, last_interval: 1)
        end

        it "does not show the review link" do
          get tag_path(mid_tag)
          expect(response.body).not_to include(review_path(tag_id: mid_tag.id))
        end
      end
    end

    describe "GET /tags/:id (nested tag)" do
      before { leaf_tag }

      it "returns a successful response" do
        get tag_path(leaf_tag)
        expect(response).to have_http_status(:success)
      end

      it "renders the full breadcrumb ancestry" do
        get tag_path(leaf_tag)
        expect(response.body).to include(root_tag.name)
        expect(response.body).to include(mid_tag.name)
      end

      it "links to each ancestor in the breadcrumb" do
        get tag_path(leaf_tag)
        expect(response.body).to include(tag_path(root_tag))
        expect(response.body).to include(tag_path(mid_tag))
      end
    end
  end

  context "when unauthenticated" do
    describe "GET /tags" do
      it "redirects to the login page" do
        get tags_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    describe "GET /tags/:id" do
      it "redirects to the login page" do
        get tag_path(root_tag)
        expect(response).to redirect_to("/sign_in")
      end
    end
  end
end
