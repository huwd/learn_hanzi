require 'rails_helper'

RSpec.describe Source, type: :model do
  describe "associations" do
    it { should have_many(:meanings).dependent(:nullify) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }

    it "allows a valid URL" do
      should allow_value("https://example.com").for(:url)
      should allow_value("http://example.com").for(:url)
    end

    it "rejects an invalid URL" do
      should_not allow_value("invalid-url").for(:url)
      should_not allow_value("ftp://example.com").for(:url)
    end

    it "does not require a URL to be present" do
      should allow_value(nil).for(:url)
    end

    it "requires `date_accessed` if `url` is present" do
      source_with_url = build(:source, url: "https://example.com", date_accessed: nil)
      expect(source_with_url).to_not be_valid
      expect(source_with_url.errors[:date_accessed]).to include("can't be blank")

      source_without_url = build(:source, url: nil, date_accessed: nil)
      expect(source_without_url).to be_valid
    end
  end
end
