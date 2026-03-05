require 'rails_helper'

RSpec.describe "DictionaryEntries", type: :request do
  let(:user) { create(:user) }
  let(:dictionary_entry) { create(:dictionary_entry) }

  before do
    sign_in user
  end

  describe "GET /dictionary_entries/:id" do
    it "returns a successful response" do
      get dictionary_entry_path(dictionary_entry)
      expect(response).to have_http_status(:success)
    end

      it "renders the target vocab prominently" do
      get dictionary_entry_path(dictionary_entry)
      expect(response.body).to include("感动")
    end
  end
end
