namespace :anki do
  desc "Migrate data from Anki to UserLearning and ReviewLog models"
  task :migrate_to_models, [ :email ] => :environment do |t, args|
    # Validate email parameter
    unless args[:email].present?
      puts "[ERROR] Please provide an email parameter. Example: rake anki:migrate_to_models[email@example.com]"
      exit 1
    end

    # Look up the user
    email = args[:email]
    user = User.find_by(email_address: email)

    unless user
      puts "[ERROR] No user found with email: #{email}"
      exit 1
    end

    puts "Starting migration from Anki to UserLearning and ReviewLog..."

    target_deck = Anki::ANKI_DESK_TARGET
    log_file = Rails.root.join("log", "anki_migration.log")
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    File.open(log_file, "a") do |log|
      log.puts "Migrating Anki Deck: #{target_deck}"
      log.puts "---"

      # Get deck ID for the target deck
      col_metadata = Anki::DB.connection.execute("SELECT decks FROM col").first
      decks = JSON.parse(col_metadata["decks"])

      deck_id = decks.find { |_, deck| deck["name"] == target_deck }&.first

      if deck_id.nil?
        puts "[ERROR] No deck found with the name: #{target_deck}"
        exit 1
      end

      # Filter cards by deck ID, including cards currently in a filtered deck.
      # Anki stores the original deck in `odid` when moving a card to a filtered
      # deck; `did` alone misses these cards.
      cards = Anki::Card.where(did: deck_id).or(Anki::Card.where(odid: deck_id)).to_a
      card_ids = cards.map(&:id)
      note_ids  = cards.map(&:nid)

      # Pre-load all Anki data in bulk (eliminates N+1 across the Anki DB)
      notes_by_nid   = Anki::Note.where(id: note_ids).index_by(&:id)
      revlogs_by_cid = Anki::Revlog.where(cid: card_ids).group_by(&:cid)

      # Resolve the field layout once; avoids a SELECT models FROM col per note
      deck_model    = Anki.deck
      field_names   = deck_model["flds"].map { |f| f["name"] }
      simplified_idx = field_names.index("Simplified")

      # Map each card to its simplified character and queue state
      card_simplified = {}
      card_state      = {}

      cards.each do |card|
        note = notes_by_nid[card.nid]
        next unless note

        simplified = note.flds.split("\u001F")[simplified_idx]
        next if simplified.blank?

        card_simplified[card.id] = simplified
        card_state[card.id] = case card.queue
        when 0      then "new"
        when 1, 3   then "learning"
        when 2      then "mastered"
        when -1, -2 then "suspended"
        else             "unknown"
        end
      end

      # Pre-load matching DictionaryEntry IDs in one query
      simplified_chars = card_simplified.values.uniq
      entry_id_map = DictionaryEntry.where(text: simplified_chars).pluck(:text, :id).to_h

      simplified_chars.each do |text|
        log.puts "[SKIP] No DictionaryEntry for Simplified Character: #{text}" unless entry_id_map.key?(text)
      end

      # Build and bulk-insert UserLearning rows.
      # ON CONFLICT DO NOTHING preserves state for cards already imported.
      card_entry_id = {}
      user_learning_rows = cards.filter_map do |card|
        simplified = card_simplified[card.id]
        next unless simplified

        entry_id = entry_id_map[simplified]
        next unless entry_id

        card_entry_id[card.id] = entry_id
        {
          user_id:             user.id,
          dictionary_entry_id: entry_id,
          state:               card_state[card.id],
          next_due:            Time.at(card.due),
          last_interval:       card.ivl
        }
      end

      UserLearning.insert_all(user_learning_rows) if user_learning_rows.any?

      # Reload user_learning IDs for ReviewLog association
      found_entry_ids = card_entry_id.values.uniq
      ul_id_map = UserLearning
        .where(user: user, dictionary_entry_id: found_entry_ids)
        .pluck(:dictionary_entry_id, :id).to_h

      # Build and bulk-insert ReviewLog rows.
      # ON CONFLICT DO NOTHING on anki_id ensures idempotency.
      review_log_rows = cards.flat_map do |card|
        entry_id = card_entry_id[card.id]
        next [] unless entry_id

        ul_id = ul_id_map[entry_id]
        next [] unless ul_id

        (revlogs_by_cid[card.id] || []).map do |revlog|
          {
            anki_id:          revlog.id,
            user_learning_id: ul_id,
            ease:             revlog.ease,
            interval:         revlog.ivl,
            time_spent:       revlog.time,
            factor:           revlog.factor,
            time:             revlog.id,
            log_type:         revlog.type
          }
        end
      end

      ReviewLog.insert_all(review_log_rows) if review_log_rows.any?

      log.puts "---"
      log.puts "Migration complete."
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    puts "\nMigration complete. Completed in #{elapsed.round(2)}s. Log written to: #{log_file}"
  end
end
