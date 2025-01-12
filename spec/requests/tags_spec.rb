require 'rails_helper'

RSpec.describe "Tags", type: :request do
  let(:user) { create(:user) }
  let(:tag) { create(:tag) }
  let(:dictionary_entry) { create(:dictionary_entry) }

  before do
    sign_in user
    tag.dictionary_entries << dictionary_entry
  end

  describe "GET /tags" do
    it "returns a successful response" do
      get tags_path
      expect(response).to have_http_status(:success)
    end

    it "returns html containing a link with the Tag name" do
      get tags_path
      expect(response.body).to include("#{tag.name}</a>")
    end
  end

  describe "GET /tags/:id" do
    it "returns a successful response" do
      get tag_path(tag)
      expect(response).to have_http_status(:success)
    end

    it "returns html containing a H1 with the Tag name" do
      get tag_path(tag)
      expect(response.body).to include("#{tag.name}</h1>")
    end
  end
end