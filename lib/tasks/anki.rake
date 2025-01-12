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

    File.open(log_file, "a") do |log| # Open in append mode
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

      # Filter cards by deck ID
      cards = Anki::Card.where(did: deck_id)
      total_cards = cards.size
      processed_cards = 0

      cards.each do |card|
        begin
          note = Anki::Note.find(card.nid)
          simplified_character = note.card_data["Simplified"]

          next if simplified_character.blank?

          dictionary_entry = DictionaryEntry.find_by(text: simplified_character)
          unless dictionary_entry
            log.puts "[SKIP] No DictionaryEntry for Simplified Character: #{simplified_character}"
            next
          end

          # Create or find UserLearning
          user_learning = UserLearning.find_or_create_by!(
            user: user, # Take the user we passed in
            dictionary_entry: dictionary_entry
          ) do |ul|
            ul.state = case card.queue
            when 0 then "new"
            when 1 then "learning"
            when 2 then "mastered"
            when 3 then "learning" # Treat "Day Learning" as "learning"
            when -1 then "suspended"
            when -2 then "suspended" # Treat "Buried" as "suspended"
            else
              "unknown" # Fallback for unexpected states
            end
            ul.next_due = Time.at(card.due)
            ul.last_interval = card.ivl
          end

          # Migrate ReviewLogs for the card
          revlogs = Anki::Revlog.where(cid: card.id)
          revlogs.each do |revlog|
            # Skip if the ReviewLog with the same anki_id already exists
            next if ReviewLog.exists?(anki_id: revlog.id)
            ReviewLog.create!(
              anki_id: revlog.id,
              user_learning_id: user_learning.id,
              ease: revlog.ease,
              interval: revlog.ivl,
              time_spent: revlog.time,
              factor: revlog.factor,
              time: revlog.id,
              log_type: revlog.type
            )
          end

          # log.puts "[SUCCESS] Migrated Card #{card.id} -> UserLearning #{user_learning.id}"
        rescue => e
          log.puts "[ERROR] #{simplified_character}: Failed to migrate Card #{card.id}: #{e.message}"
        ensure
          processed_cards += 1
          progress = (processed_cards.to_f / total_cards * 100).round(2)
          print "\r(#{processed_cards} of #{total_cards}) #{progress}%"
        end
      end

      log.puts "---"
      log.puts "Migration complete."
    end

    puts "\nMigration complete. Log written to: #{log_file}"
  end
end
