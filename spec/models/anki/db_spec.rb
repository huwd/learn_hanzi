require 'rails_helper'

# Helpers to introspect the test Anki SQLite database directly.
module AnkiDBSpecHelpers
  def columns_of(table)
    Anki::DB.connection
            .execute("PRAGMA table_info(#{table})")
            .map { |r| r["name"] }
  end

  def model_ids_in_col
    col = Anki::DB.connection.execute("SELECT models FROM col").first
    JSON.parse(col["models"]).keys
  end

  def seeded_queue_values
    Anki::DB.connection
            .execute("SELECT DISTINCT queue FROM cards")
            .map { |r| r["queue"] }
  end
end

RSpec.describe Anki::DB, type: :model do
  include AnkiDBSpecHelpers

  describe "schema" do
    it "exposes all required Anki tables" do
      tables = Anki::DB.connection
                       .execute("SELECT name FROM sqlite_master WHERE type='table'")
                       .map { |r| r["name"] }
      expect(tables).to include("notes", "cards", "revlog", "col", "graves")
    end

    it "notes table has the expected columns" do
      expect(columns_of("notes")).to match_array(
        %w[id guid mid mod usn tags flds sfld csum flags data]
      )
    end

    it "cards table has the expected columns" do
      expect(columns_of("cards")).to match_array(
        %w[id nid did ord mod usn type queue due ivl factor reps lapses left odue odid flags data]
      )
    end

    it "revlog table has the expected columns" do
      expect(columns_of("revlog")).to match_array(
        %w[id cid usn ease ivl lastIvl factor time type]
      )
    end

    it "col table has the expected columns" do
      expect(columns_of("col")).to match_array(
        %w[id crt mod scm ver dty usn ls conf models decks dconf tags]
      )
    end
  end

  describe "seed data integrity" do
    it "notes reference a model id that exists in col" do
      note_mids = Anki::DB.connection
                           .execute("SELECT DISTINCT mid FROM notes")
                           .map { |r| r["mid"].to_s }
      expect(note_mids).to all(be_in(model_ids_in_col))
    end

    it "the target deck is configured in col" do
      col = Anki::DB.connection.execute("SELECT decks FROM col").first
      deck_names = JSON.parse(col["decks"]).values.map { |d| d["name"] }
      expect(deck_names).to include(Anki::ANKI_DESK_TARGET)
    end

    it "seeds cards covering all queue state variants" do
      expected_queues = [ 0, 1, 2, 3, -1, -2 ]
      expect(seeded_queue_values).to include(*expected_queues)
    end

    it "seeds a regression anchor: a note with no importable DictionaryEntry match" do
      # Card 8 (不) has no DictionaryEntry — must be present to guard the skip path
      skippable = Anki::DB.connection
                           .execute("SELECT sfld FROM notes WHERE sfld = '不'")
      expect(skippable).not_to be_empty
    end

    it "each card's nid references an existing note" do
      note_ids  = Anki::DB.connection.execute("SELECT id FROM notes").map { |r| r["id"] }
      card_nids = Anki::DB.connection.execute("SELECT nid FROM cards").map { |r| r["nid"] }
      expect(card_nids).to all(be_in(note_ids))
    end

    it "each revlog entry's cid references an existing card" do
      card_ids   = Anki::DB.connection.execute("SELECT id FROM cards").map { |r| r["id"] }
      revlog_cids = Anki::DB.connection.execute("SELECT cid FROM revlog").map { |r| r["cid"] }
      expect(revlog_cids).to all(be_in(card_ids))
    end
  end
end
