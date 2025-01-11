module Anki
  class DB < ReadOnlyRecord
    self.abstract_class = true

    connects_to database: { writing: :anki, reading: :anki }
  end

  class Note < DB
    self.table_name = "notes"
    self.primary_key = "id"
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
end
