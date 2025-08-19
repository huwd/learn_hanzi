module Anki
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
      candidates.select do |note|
        note.card_data["Simplified"] == character
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
