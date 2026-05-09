module Admin
  class MakemeahanziSourceProvisioningService
    include ImportFilesHelper

    DICTIONARY_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt"
    GRAPHICS_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt"
    OUTPUT_DIR = Rails.root.join("tmp", "makemeahanzi")
    DICTIONARY_PATH = OUTPUT_DIR.join("dictionary.txt")
    GRAPHICS_PATH = OUTPUT_DIR.join("graphics.txt")

    def self.call(force: true)
      new(force: force).call
    end

    def initialize(force: true)
      @force = force
    end

    def call
      download!(DICTIONARY_URL, DICTIONARY_PATH)
      download!(GRAPHICS_URL, GRAPHICS_PATH)

      {
        dictionary_path: DICTIONARY_PATH.to_s,
        dictionary_bytes: File.size(DICTIONARY_PATH),
        graphics_path: GRAPHICS_PATH.to_s,
        graphics_bytes: File.size(GRAPHICS_PATH)
      }
    end

    def self.dictionary_path
      DICTIONARY_PATH
    end

    def self.graphics_path
      GRAPHICS_PATH
    end

    private

    def download!(url, path)
      return if path.exist? && !@force

      download_file_to_tmp(url, path.to_s)
      confirm_file_presence(path.basename.to_s, path.dirname)
    end
  end
end
