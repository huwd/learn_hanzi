module Anki
  # Going to hard code the ANKI target for now
  # Mostly as we're dealing with a single read only DB
  # I know what's in it
  # However this is something we'll want to vary, to allow
  # A user to upload and select their own ANKI table and match
  # with dictionary entries
  ANKI_DESK_TARGET = "Mandarin: Vocabulary::a. HSK"

  class DB < ReadOnlyRecord
    self.abstract_class = true

    connects_to database: { writing: :anki, reading: :anki }
  end

  class Note < DB
    self.table_name = "notes"
    self.primary_key = "id"

    def self.find_by_character(character)
      candidates = Anki::Note.where("flds LIKE ?", "%#{character}%")
      results = candidates.select do |note|
        data = note.card_data  # => e.g., { "Simplified" => "...", "Pinyin" => "...", ...}
        data["Simplified"] == "好"
      end
    end

    def card_data
      if anki_deck.present?
        field_names = anki_deck["flds"].map { |f| f["name"] }
        Hash[field_names.zip(flds.split("\u001F"))]
      end
    end

    def anki_deck
      @anki_deck ||= Anki.deck
    end
  end

  class Card < DB
    self.table_name = "cards"
    self.primary_key = "id"
    self.inheritance_column = :_type_disabled
  end

  class Revlog < DB
    self.table_name = "revlog"
    self.primary_key = "id"
    self.inheritance_column = :_type_disabled
  end

  def self.deck
    models_json = Anki::DB.connection.execute("SELECT models FROM col").first["models"]
    models = JSON.parse(models_json)
    models.find { |_, model| model["name"] == "HSK" }[1]
  end
end
