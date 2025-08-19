require 'rails_helper'

RSpec.describe Anki::DB, type: :model do
  describe ".connection" do
    it "returns a valid SQLite3::Database connection" do
      expect(Anki::DB.connection).to be_a(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
    end

    it "connects to the correct database" do
      result = Anki::DB.connection.execute("SELECT name FROM sqlite_master WHERE type='table'")
      expect(result.flatten).to include(
       { "name"=>"android_metadata" },
       { "name"=>"cards" },
       { "name"=>"col" },
       { "name"=>"graves" },
       { "name"=>"notes" },
       { "name"=>"revlog" },
       { "name"=>"schema_migrations" },
       { "name"=>"ar_internal_metadata" }
      )
    end

    it "has at least one entry in the cards table" do
      result = Anki::DB.connection.execute("SELECT COUNT(*) FROM cards")
      expect(result.first['COUNT(*)']).to be > 0
    end

    it "has at least one entry in the notes table" do
      result = Anki::DB.connection.execute("SELECT COUNT(*) FROM notes")
      expect(result.first['COUNT(*)']).to be > 0
    end

    it "has at least one entry in the revlog table" do
      result = Anki::DB.connection.execute("SELECT COUNT(*) FROM revlog")
      expect(result.first['COUNT(*)']).to be > 0
    end
  end
end
