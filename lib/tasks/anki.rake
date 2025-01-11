namespace :anki do
  desc "Analyze compatibility of the ANKI_TARGET_DECK with DictionaryEntries"
  task analyze_deck: :environment do
    # Safeguard 1: Check if the Anki SQLite DB exists
    anki_db_path = Anki::DB.connection_db_config.database
    unless File.exist?(anki_db_path)
      puts "[ERROR] Anki SQLite database not found at: #{anki_db_path}"
      exit 1
    end

    # Safeguard 2: Test connection to the Anki database
    begin
      Anki::DB.connection.execute("SELECT 1")
    rescue => e
      puts "[ERROR] Unable to connect to Anki SQLite database: #{e.message}"
      exit 1
    end

    # Load the target deck from Anki module
    target_deck = Anki::ANKI_DESK_TARGET
    log_file = Rails.root.join("log", "anki_deck_analysis.log")

    File.open(log_file, "w") do |log|
      log.puts "Analyzing Anki Deck: #{target_deck}"
      log.puts "---"

      # Get deck ID for the target deck name from the col table
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
          # Fetch the associated note
          note = Anki::Note.find(card.nid)

          # Extract the simplified character from the note
          simplified_character = note.card_data["Simplified"]

          if simplified_character.blank?
            log.puts "[WARNING] Card #{card.id}: No simplified character found in note #{note.id}"
            next
          end

          # Check if the character exists in the DictionaryEntries table
          dictionary_entry = DictionaryEntry.find_by(text: simplified_character)

          if dictionary_entry.nil?
            log.puts "[MISSING] Card #{card.id}, Note #{note.id}: Simplified character '#{simplified_character}' not found in DictionaryEntries"
          end
        rescue => e
          log.puts "[ERROR] Card #{card.id}: #{e.message}"
        ensure
          processed_cards += 1
          progress = (processed_cards.to_f / total_cards * 100).round
          print "\r#{'=' * (progress / 10)}#{'>'} (#{processed_cards}/#{total_cards}) #{progress}%"
        end
      end

      log.puts "---"
      log.puts "Analysis complete."
    end

    puts "\nAnalysis complete. Log written to: #{log_file}"
  end
end
