module Admin
  class CcCedictProvisioningService
    include ImportFilesHelper
    include DictionaryImportHelper

    CEDICT_URL     = "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
    CEDICT_ZIP     = Rails.root.join("tmp", "cedict.zip")
    CEDICT_DIR     = Rails.root.join("tmp", "cedict")
    CEDICT_FILE    = Rails.root.join("tmp", "cedict", "cedict_ts.u8")

    def self.call
      new.call
    end

    def call
      entries_before = DictionaryEntry.count

      download_file_to_tmp(CEDICT_URL, CEDICT_ZIP)
      unzip_file(CEDICT_ZIP, CEDICT_DIR)
      confirm_file_presence("*cedict*", CEDICT_DIR)

      source = find_or_create_cc_cedict_source(
        "CC-CEDICT",
        "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
      )
      lines = File.readlines(CEDICT_FILE)
      batch_import_cc_cedict_lines(lines, source)

      { entries_before: entries_before, entries_after: DictionaryEntry.count }
    end
  end
end
