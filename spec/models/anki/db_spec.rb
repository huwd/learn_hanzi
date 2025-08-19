require 'rails_helper'

# Go manually hack the DB to add:
# INSERT INTO cards (nid, ord, mod, usn, did, queue, due, ivl, reps, lapses, left, factor, type, odue, odid, flags, data) VALUES (1, 1, 1, 1, 1, 1, 1622505600, 10, 4, 1, 1, 10, 0, 1, 1, 1, "")
# INSERT INTO notes (guid, mid, mod, tags, sfld, usn, csum, flags, flds, data) VALUES ("abc", 1, 1, 1, 1, 1, 1, 1, '20\u001F很\u001F很\u001Fhěn\u001Fhen3\u001Fvery; quite\u001Fadverb\u001F[sound:hen3.mp3]\u001F\u001F\u001F你做得<b>很</b>好。\u001F你做得<b>很</b>好。\u001F你做得[ ]好。\u001F你 得[ ]好。\u001FNǐ zuò de hěn hǎo.\u001FNi3 zuo4 de hen3 hao3.\u001FYou've done great.\u001F[sound:tmpzbp6hb.mp3]\u001F<img src=\"4839396.jpg\" />', '' )
# INSERT INTO revlog (cid, usn, lastIvl, ease, ivl, time, factor, type) VALUES (1, 1, 1, 2, 10, 300, 2500, 1)

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
       { "name"=>"sqlite_sequence" },
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
