require 'rails_helper'

RSpec.describe "DictionaryEntries", type: :request do
  let(:user) { create(:user) }
  let(:dictionary_entry) { create(:dictionary_entry) }

  context "when authenticated" do
    before { sign_in user }

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

  context "when unauthenticated" do
    describe "GET /dictionary_entries/:id" do
      it "redirects to the login page" do
        get dictionary_entry_path(dictionary_entry)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
