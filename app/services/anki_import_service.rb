class AnkiImportService
  DECK_NAME = "Mandarin: Vocabulary::a. HSK"
  SEP = "\u001F"
  ALLOWED_STATES = {
    0  => "new",
    1  => "learning",
    2  => "mastered",
    3  => "learning",
    -1 => "suspended",
    -2 => "suspended"
  }.freeze

  def self.call(user:, file_path:)
    new(user: user, file_path: file_path).call
  end

  def initialize(user:, file_path:)
    @user = user
    @file_path = file_path
  end

  def call
    db = SQLite3::Database.new(@file_path, readonly: true)
    db.results_as_hash = true

    col        = db.execute("SELECT crt, decks, models FROM col").first
    col_crt    = col["crt"].to_i
    decks      = JSON.parse(col["decks"])
    models     = JSON.parse(col["models"])
    deck_id    = decks.find { |_, d| d["name"] == DECK_NAME }&.first

    raise "No deck found: #{DECK_NAME}" unless deck_id

    field_names    = models.values.first["flds"].map { |f| f["name"] }
    simplified_idx = field_names.index("Simplified")

    cards = db.execute(
      "SELECT id, nid, queue, due, ivl FROM cards WHERE did = ? OR odid = ?",
      [ deck_id, deck_id ]
    )

    card_ids = cards.map { |c| c["id"] }
    note_ids = cards.map { |c| c["nid"] }.uniq

    placeholders = note_ids.map { "?" }.join(",")
    notes_by_id  = db.execute(
      "SELECT id, flds FROM notes WHERE id IN (#{placeholders})", note_ids
    ).index_by { |n| n["id"] }

    card_simplified = {}
    card_state      = {}

    cards.each do |card|
      note = notes_by_id[card["nid"]]
      next unless note

      simplified = note["flds"].split(SEP)[simplified_idx]
      next if simplified.blank?

      card_simplified[card["id"]] = simplified
      card_state[card["id"]]      = ALLOWED_STATES.fetch(card["queue"], "unknown")
    end

    chars        = card_simplified.values.uniq
    entry_id_map = DictionaryEntry.where(text: chars).pluck(:text, :id).to_h
    skipped      = chars.reject { |c| entry_id_map.key?(c) }

    card_entry_id = {}
    ul_rows = cards.filter_map do |card|
      simplified = card_simplified[card["id"]]
      next unless simplified

      entry_id = entry_id_map[simplified]
      next unless entry_id

      card_entry_id[card["id"]] = entry_id
      {
        user_id:             @user.id,
        dictionary_entry_id: entry_id,
        state:               card_state[card["id"]],
        next_due:            anki_next_due(card, col_crt),
        last_interval:       card["ivl"]
      }
    end

    UserLearning.insert_all(ul_rows) if ul_rows.any?

    found_entry_ids = card_entry_id.values.uniq
    ul_id_map = UserLearning
      .where(user: @user, dictionary_entry_id: found_entry_ids)
      .pluck(:dictionary_entry_id, :id).to_h

    revlogs = []
    if card_ids.any?
      revlog_placeholders = card_ids.map { "?" }.join(",")
      revlogs = db.execute(
        "SELECT id, cid, ease, ivl, factor, time, type FROM revlog WHERE cid IN (#{revlog_placeholders})",
        card_ids
      )
    end

    revlog_rows = revlogs.filter_map do |revlog|
      entry_id = card_entry_id[revlog["cid"]]
      next unless entry_id

      ul_id = ul_id_map[entry_id]
      next unless ul_id

      {
        anki_id:          revlog["id"],
        user_learning_id: ul_id,
        ease:             revlog["ease"],
        interval:         revlog["ivl"],
        time_spent:       revlog["time"],
        factor:           revlog["factor"],
        time:             revlog["id"],
        log_type:         revlog["type"]
      }
    end

    ReviewLog.insert_all(revlog_rows) if revlog_rows.any?

    {
      cards_imported:       ul_rows.size,
      review_logs_imported: revlog_rows.size,
      skipped:              skipped
    }
  ensure
    db&.close
  end

  private

  def anki_next_due(card, col_crt)
    case card["queue"]
    when 0      then nil
    when 1, 3   then Time.at(card["due"].to_i)
    when 2      then Time.at(col_crt + card["due"].to_i * 86_400)
    else             nil
    end
  end
end
