require 'sqlite3'
require 'fileutils'

module AnkiHelper
  # Use the configured path from database.yml
  def self.test_db_path
    Rails.application.config.database_configuration['test']['anki']['database']
  end

  def self.setup_test_db
    unless File.exist?(test_db_path)
      FileUtils.mkdir_p(File.dirname(test_db_path))
      db = SQLite3::Database.new(test_db_path)
      create_db(db)
      seed_db(db)
      db.close
    else
    end
    true
  end

  def self.recreate_test_db!
    FileUtils.rm_f(test_db_path) if File.exist?(test_db_path)
    setup_test_db
  end

  def self.create_db(db)
    db.execute <<-SQL
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY,
        guid TEXT,
        mid INTEGER,
        mod INTEGER,
        usn INTEGER,
        tags TEXT,
        flds TEXT,
        sfld TEXT,
        csum INTEGER,
        flags INTEGER,
        data TEXT
      );
    SQL

    db.execute <<-SQL
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY,
        nid INTEGER,
        did INTEGER,
        ord INTEGER,
        mod INTEGER,
        usn INTEGER,
        type INTEGER,
        queue INTEGER,
        due INTEGER,
        ivl INTEGER,
        factor INTEGER,
        reps INTEGER,
        lapses INTEGER,
        left INTEGER,
        odue INTEGER,
        odid INTEGER,
        flags INTEGER,
        data TEXT
      );
    SQL

    db.execute <<-SQL
      CREATE TABLE revlog (
        id INTEGER PRIMARY KEY,
        cid INTEGER,
        usn INTEGER,
        ease INTEGER,
        ivl INTEGER,
        lastIvl INTEGER,
        factor INTEGER,
        time INTEGER,
        type INTEGER
      );
    SQL

    db.execute <<-SQL
      CREATE TABLE col (
        id INTEGER PRIMARY KEY,
        crt INTEGER,
        mod INTEGER,
        scm INTEGER,
        ver INTEGER,
        dty INTEGER,
        usn INTEGER,
        ls INTEGER,
        conf TEXT,
        models TEXT,
        decks TEXT,
        dconf TEXT,
        tags TEXT
      );
    SQL

    db.execute <<-SQL
      CREATE TABLE android_metadata (locale TEXT);
    SQL

    db.execute <<-SQL
      CREATE TABLE graves (usn INTEGER, oid INTEGER, type INTEGER);
    SQL

    db.execute <<-SQL
      CREATE TABLE schema_migrations (version VARCHAR(255) PRIMARY KEY);
    SQL

    db.execute <<-SQL
      CREATE TABLE ar_internal_metadata (key VARCHAR(255) PRIMARY KEY, value TEXT, created_at DATETIME, updated_at DATETIME);
    SQL
  end

  def self.seed_db(db)
    # Notes: one per queue state variant, plus one with no matching DictionaryEntry
    notes = [
      [ 1, "note001", "20\u001F好\u001F好\u001Fhǎo\u001Fhao3\u001Fgood; well\u001Fadjective\u001F[sound:hao3.mp3]", "好" ],
      [ 2, "note002", "21\u001F很\u001F很\u001Fhěn\u001Fhen3\u001Fvery; quite\u001Fadverb\u001F[sound:hen3.mp3]", "很" ],
      [ 3, "note003", "30\u001F学\u001F學\u001Fxué\u001Fxue2\u001Fto study\u001Fverb\u001F", "学" ],
      [ 4, "note004", "40\u001F天\u001F天\u001Ftiān\u001Ftian1\u001Fday; sky\u001Fnoun\u001F", "天" ],
      [ 5, "note005", "50\u001F人\u001F人\u001Frén\u001Fren2\u001Fperson\u001Fnoun\u001F", "人" ],
      [ 6, "note006", "60\u001F大\u001F大\u001Fdà\u001Fda4\u001Fbig\u001Fadjective\u001F", "大" ],
      [ 7, "note007", "70\u001F小\u001F小\u001Fxiǎo\u001Fxiao3\u001Fsmall\u001Fadjective\u001F", "小" ],
      [ 8, "note008", "80\u001F不\u001F不\u001Fbù\u001Fbu4\u001Fnot\u001Fadverb\u001F", "不" ]
    ]
    notes.each do |id, guid, flds, sfld|
      db.execute(
        "INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data) VALUES (?, ?, 1, 1234567890, -1, '', ?, ?, 1, 0, '')",
        [ id, guid, flds, sfld ]
      )
    end

    # Cards: one per note, covering all queue variants
    # queue: 2=mastered, 2=mastered, 0=new, 1=learning, 3=day-learning, -1=suspended, -2=buried, 2=no-entry
    cards = [
      [ 1, 1, 2, 1234567890 ],
      [ 2, 2, 2, 1234567890 ],
      [ 3, 3, 0, 0 ],
      [ 4, 4, 1, 1234567890 ],
      [ 5, 5, 3, 1234567890 ],
      [ 6, 6, -1, 1234567890 ],
      [ 7, 7, -2, 1234567890 ],
      [ 8, 8, 2, 1234567890 ]
    ]
    cards.each do |id, nid, queue, due|
      db.execute(
        "INSERT INTO cards (id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, reps, lapses, left, odue, odid, flags, data) VALUES (?, ?, 1, 0, 1234567890, -1, 2, ?, ?, 250, 2500, 5, 0, 2, 0, 0, 0, '')",
        [ id, nid, queue, due ]
      )
    end

    # Revlogs: one per card
    (1..8).each do |i|
      db.execute(
        "INSERT INTO revlog (id, cid, usn, ease, ivl, lastIvl, factor, time, type) VALUES (?, ?, -1, 2, 250, 100, 2500, 5000, 1)",
        [ i, i ]
      )
    end

    # Col: models JSON defines field names; decks JSON maps deck id → name
    models_json = {
      "1234567890" => {
        "name" => "HSK",
        "flds" => [
          { "name" => "ID", "ord" => 0 },
          { "name" => "Simplified", "ord" => 1 },
          { "name" => "Traditional", "ord" => 2 },
          { "name" => "Pinyin", "ord" => 3 },
          { "name" => "Audio", "ord" => 4 },
          { "name" => "English", "ord" => 5 },
          { "name" => "Part of Speech", "ord" => 6 },
          { "name" => "Audio Sentence", "ord" => 7 }
        ]
      }
    }.to_json

    decks_json = {
      "1" => { "name" => "Mandarin: Vocabulary::a. HSK" }
    }.to_json

    db.execute(
      "INSERT INTO col (id, crt, mod, scm, ver, dty, usn, ls, conf, models, decks, dconf, tags) VALUES (1, 1234567890, 1234567890, 1234567890, 11, 0, 0, 0, '{}', ?, ?, '{}', '{}')",
      [ models_json, decks_json ]
    )
  end
end
