require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#hanzi_size_class" do
    it "returns text-9xl for a single character" do
      expect(helper.hanzi_size_class("你")).to eq("text-9xl")
    end

    it "returns text-9xl for two characters" do
      expect(helper.hanzi_size_class("你好")).to eq("text-9xl")
    end

    it "returns text-8xl for three characters" do
      expect(helper.hanzi_size_class("你好吗")).to eq("text-8xl")
    end

    it "returns text-7xl for four or more characters" do
      expect(helper.hanzi_size_class("你好吗？")).to eq("text-7xl")
    end
  end
end
