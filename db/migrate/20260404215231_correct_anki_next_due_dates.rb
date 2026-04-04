class CorrectAnkiNextDueDates < ActiveRecord::Migration[8.1]
  # Records with next_due before this cutoff have an epoch-relative date from
  # the broken import. No valid Anki review date can predate Anki's existence.
  EPOCH_CUTOFF = Time.utc(2000, 1, 1).freeze

  def up
    col      = Anki::DB.connection.execute("SELECT crt, decks FROM col").first
    col_crt  = col["crt"]
    deck_id  = deck_id_from(col["decks"])

    unless deck_id
      say "Target deck not found — skipping"
      return
    end

    fix_mastered_cards(deck_id, col_crt)
    fix_mastered_cards_from_review_logs
    fix_new_cards(deck_id)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def deck_id_from(decks_json)
    decks = JSON.parse(decks_json)
    decks.find { |_, d| d["name"] == Anki::ANKI_DESK_TARGET }&.first
  end

  def simplified_idx
    @simplified_idx ||= Anki.deck["flds"].map { |f| f["name"] }.index("Simplified")
  end

  # Build simplified_char → next_due map for the given queue value(s).
  # col_crt is nil for queue=0 (new) cards, producing nil next_due values.
  def char_to_next_due(deck_id, queues:, col_crt: nil)
    cards = Anki::Card.where(did: deck_id).or(Anki::Card.where(odid: deck_id))
                      .where(queue: queues)
    notes = Anki::Note.where(id: cards.map(&:nid)).index_by(&:id)

    cards.each_with_object({}) do |card, map|
      note = notes[card.nid]
      next unless note

      char = note.flds.split("\u001F")[simplified_idx].presence
      next unless char

      map[char] = col_crt ? Time.at(col_crt + card.due * 86_400) : nil
    end
  end

  def fix_mastered_cards(deck_id, col_crt)
    char_map = char_to_next_due(deck_id, queues: 2, col_crt: col_crt)

    updated = 0
    DictionaryEntry.where(text: char_map.keys).find_each do |entry|
      n = UserLearning
            .where(dictionary_entry: entry, state: "mastered")
            .where("next_due < ?", EPOCH_CUTOFF)
            .update_all(next_due: char_map[entry.text])
      updated += n
    end

    say "Corrected next_due for #{updated} mastered UserLearning records"
  end

  # Fallback for mastered records still carrying epoch dates after the first
  # pass — typically cards that have since moved to a different Anki deck so
  # their due value can no longer be looked up. Reconstructs next_due from
  # the most recent ReviewLog: review_time + last_interval days.
  def fix_mastered_cards_from_review_logs
    remaining = UserLearning
                  .where(state: "mastered")
                  .where("next_due < ?", EPOCH_CUTOFF)
                  .includes(:review_logs)

    updated = 0
    remaining.each do |ul|
      last_log = ul.review_logs.max_by(&:time)
      next unless last_log

      correct_due = Time.at(last_log.time / 1000.0) + ul.last_interval.days
      ul.update_columns(next_due: correct_due)
      updated += 1
    end

    say "Reconstructed next_due from review logs for #{updated} mastered UserLearning records"
  end

  def fix_new_cards(deck_id)
    char_map = char_to_next_due(deck_id, queues: 0)

    updated = 0
    DictionaryEntry.where(text: char_map.keys).find_each do |entry|
      n = UserLearning
            .where(dictionary_entry: entry, state: "new")
            .where("next_due < ?", EPOCH_CUTOFF)
            .update_all(next_due: nil)
      updated += n
    end

    say "Cleared next_due for #{updated} new UserLearning records"
  end
end
