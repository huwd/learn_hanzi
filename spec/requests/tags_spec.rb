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
        expect(response).to redirect_to(new_session_path)
      end
    end

    describe "GET /tags/:id" do
      it "redirects to the login page" do
        get tag_path(root_tag)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
