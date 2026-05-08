class BackfillSourcePriorities < ActiveRecord::Migration[8.1]
  class MigrationSource < ApplicationRecord
    self.table_name = "sources"
  end

  def up
    MigrationSource.where(name: "CC-CEDICT").update_all(priority: 20)
    MigrationSource.where(name: "Wiktionary").update_all(priority: 50)
    MigrationSource.where(name: "Unihan").update_all(priority: 200)
  end

  def down
    MigrationSource.where(name: [ "CC-CEDICT", "Wiktionary", "Unihan" ]).update_all(priority: 100)
  end
end
