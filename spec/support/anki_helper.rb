require 'sqlite3'

module AnkiHelper
  DUMMY_DB_PATH = Rails.root.join('spec', 'fixtures', 'test_anki.db')

  def self.setup_test_db
    if File.exist?(DUMMY_DB_PATH)
      db = SQLite3::Database.new(DUMMY_DB_PATH.to_s)

      return true if db_schema_is_valid?(db)

      File.delete(DUMMY_DB_PATH)
      create_dummy_db(db)
      seed_db(db)
    end
    true
  end

  def self.db_schema_is_valid?(db)
    required_tables = %w[notes cards revlog]
    existing_tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
    existing_tables == required_tables
  end

  def self.seed_db(db)
    db.execute "INSERT INTO notes (flds) VALUES ('{\"Simplified\":\"好\",\"Pinyin\":\"hǎo\"}')"
    db.execute "INSERT INTO cards (nid, did, queue, due, ivl) VALUES (1, 1, 1, 1622505600, 10)"
    db.execute "INSERT INTO revlog (cid, ease, ivl, time, factor, type) VALUES (1, 2, 10, 300, 2500, 1)"
  end

  def self.create_db(db)
    db.execute <<-SQL
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY,
        flds TEXT
      );
    SQL

    db.execute <<-SQL
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY,
        nid INTEGER,
        did INTEGER,
        queue INTEGER,
        due INTEGER,
        ivl INTEGER
      );
    SQL

    db.execute <<-SQL
      CREATE TABLE revlog (
        id INTEGER PRIMARY KEY,
        cid INTEGER,
        ease INTEGER,
        ivl INTEGER,
        time INTEGER,
        factor INTEGER,
        type INTEGER
      );
    SQL
  end
end
