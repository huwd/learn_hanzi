require "yaml"

module Admin
  class CustomDictionaryProvisioningService
    YAML_FILE = Rails.root.join("db", "custom_dictionary_entries.yml")

    def self.call
      new.call
    end

    def call
      data    = YAML.load_file(YAML_FILE)
      entries = data["entries"]
      source  = Source.find_or_create_by!(name: "learn_hanzi")
      created = 0
      updated = 0

      entries.each do |entry_data|
        de     = DictionaryEntry.find_or_initialize_by(text: entry_data["text"])
        is_new = de.new_record?

        entry_data["meanings"].each do |m|
          next if de.meanings.exists?(text: m["text"], language: "en", source: source)
          de.meanings.build(text: m["text"], pinyin: m["pinyin"], language: "en", source: source)
        end

        de.save!
        is_new ? (created += 1) : (updated += 1)
      end

      { created: created, updated: updated }
    end
  end
end
