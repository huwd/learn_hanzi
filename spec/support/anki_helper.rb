require 'sqlite3'
require 'fileutils'
require_relative 'anki_seed_data'

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
    AnkiSeedData::NOTES.each do |note|
      db.execute(
        "INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data) " \
        "VALUES (?, ?, ?, 1234567890, -1, '', ?, ?, 1, 0, '')",
        [ note[:id], note[:guid], AnkiSeedData::MODEL_ID.to_i, note[:flds], note[:sfld] ]
      )
    end

    AnkiSeedData::CARDS.each do |card|
      db.execute(
        "INSERT INTO cards (id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, " \
        "reps, lapses, left, odue, odid, flags, data) " \
        "VALUES (?, ?, ?, 0, 1234567890, -1, 2, ?, ?, 250, 2500, 5, 0, 2, 0, 0, 0, '')",
        [ card[:id], card[:nid], AnkiSeedData::DECK_ID.to_i, card[:queue], card[:due] ]
      )
    end

    AnkiSeedData::REVLOGS.each do |revlog|
      db.execute(
        "INSERT INTO revlog (id, cid, usn, ease, ivl, lastIvl, factor, time, type) " \
        "VALUES (?, ?, -1, 2, 250, 100, 2500, 5000, 1)",
        [ revlog[:id], revlog[:cid] ]
      )
    end

    models_json = {
      AnkiSeedData::MODEL_ID => {
        "name" => AnkiSeedData::MODEL_NAME,
        "flds" => AnkiSeedData::FIELD_NAMES.each_with_index.map { |name, i| { "name" => name, "ord" => i } }
      }
    }.to_json

    decks_json = {
      AnkiSeedData::DECK_ID => { "name" => AnkiSeedData::DECK_NAME }
    }.to_json

    db.execute(
      "INSERT INTO col (id, crt, mod, scm, ver, dty, usn, ls, conf, models, decks, dconf, tags) " \
      "VALUES (1, 1234567890, 1234567890, 1234567890, 11, 0, 0, 0, '{}', ?, ?, '{}', '{}')",
      [ models_json, decks_json ]
    )
  end
end
