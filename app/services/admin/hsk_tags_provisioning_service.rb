module Admin
  class HskTagsProvisioningService
    include ImportFilesHelper
    include TagImportHelper

    HSK_2_REPO_ROOT = "https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/wordlists/exclusive/"
    HSK_2_FILES     = (1..6).to_a.map { |lvl| HSK_2_REPO_ROOT + "old/#{lvl}.min.json" }

    HSK_3_TXT_ROOT = "https://raw.githubusercontent.com/krmanik/HSK-3.0/main/New%20HSK%20(2021)/HSK%20List/"
    HSK_3_TSV_ROOT = "https://raw.githubusercontent.com/krmanik/HSK-3.0/main/Scripts%20and%20data/tsv/"
    HSK_3_LEVELS   = [ "HSK 1", "HSK 2", "HSK 3", "HSK 4", "HSK 5", "HSK 6", "HSK 7-9" ].freeze

    def self.call
      new.call
    end

    def call
      tags_created    = 0
      entries_tagged  = 0
      skipped         = 0

      download_hsk_2
      download_hsk_3

      top_tag = find_or_create_tag("HSK", "HSK")

      # Import HSK 2
      hsk2_parent = find_or_create_tag("HSK 2.0", "HSK", top_tag.id)
      top_tag.add_child(hsk2_parent)
      tags_created += 1
      hsk_2_files.each do |file|
        tag_name = "HSK #{File.basename(file, ".min.json")}"
        tag = find_or_create_tag(tag_name, "HSK", hsk2_parent.id)
        hsk2_parent.add_child(tag)
        tags_created += 1
        texts = JSON.parse(File.read(file)).map { |entry| entry["s"] }
        skipped += batch_associate_entries_to_tag(texts, tag)
        entries_tagged += texts.count - skipped
      end

      # Import HSK 3
      hsk3_parent = find_or_create_tag("HSK 3.0", "HSK", top_tag.id)
      top_tag.add_child(hsk3_parent)
      tags_created += 1
      hsk_3_files.each do |file|
        next unless File.extname(file) == ".txt"

        tag_name = File.basename(file, ".txt")
        tag = find_or_create_tag(tag_name, "HSK", hsk3_parent.id)
        hsk3_parent.add_child(tag)
        tags_created += 1
        texts = hsk3_texts_from_file(file)
        stub_count = create_hsk3_stubs(texts, file)
        skipped_count = batch_associate_entries_to_tag(texts, tag)
        skipped += skipped_count
        entries_tagged += texts.count - skipped_count
      end

      { tags_created: tags_created, entries_tagged: entries_tagged, skipped: skipped }
    end

    private

    def download_hsk_2
      file_dir = Rails.root.join("tmp", "hsk_2")
      HSK_2_FILES.each do |file_url|
        file_name = file_url.split("old/")[-1]
        file_path = Rails.root.join(file_dir, file_name)
        download_file_to_tmp(file_url, file_path)
        confirm_file_presence(file_name, file_dir)
      end
    end

    def download_hsk_3
      file_dir = Rails.root.join("tmp", "hsk_3")
      HSK_3_LEVELS.each do |level|
        txt_name = "#{level}.txt"
        download_file_to_tmp(
          HSK_3_TXT_ROOT + txt_name.gsub(" ", "%20"),
          Rails.root.join(file_dir, txt_name)
        )
        confirm_file_presence(txt_name, file_dir)

        tsv_name = "#{level}.tsv"
        download_file_to_tmp(
          HSK_3_TSV_ROOT + tsv_name.gsub(" ", "%20"),
          Rails.root.join(file_dir, tsv_name)
        )
        confirm_file_presence(tsv_name, file_dir)
      end
    end

    def hsk_2_files
      Dir.glob(Rails.root.join("tmp", "hsk_2", "*.json"))
    end

    def hsk_3_files
      Dir.glob(Rails.root.join("tmp", "hsk_3", "*.txt"))
    end

    def hsk3_texts_from_file(file)
      File.readlines(file, chomp: true)
          .map { |line| line.sub(/\A\uFEFF/, "").strip }
          .reject(&:empty?)
    end

    def create_hsk3_stubs(texts, txt_file)
      tsv_file = txt_file.sub(/\.txt$/, ".tsv")
      return 0 unless File.exist?(tsv_file)

      missing = texts - DictionaryEntry.where(text: texts).pluck(:text)
      return 0 if missing.empty?

      source = krmanik_source
      tsv_lookup = parse_tsv_lookup(tsv_file)
      stubbed = 0

      missing.each do |text|
        row = tsv_lookup[text]
        next unless row

        DictionaryEntry.transaction do
          entry = DictionaryEntry.new(text: text)
          entry.meanings.build(
            text: row[:definition], pinyin: row[:pinyin], language: "en", source: source
          )
          entry.save!
        end
        stubbed += 1
      rescue ActiveRecord::RecordNotUnique
        stubbed += 1
      end

      stubbed
    end

    def parse_tsv_lookup(tsv_file)
      File.readlines(tsv_file, chomp: true).each_with_object({}) do |line, lookup|
        parts = line.split("\t")
        next unless parts.length >= 4
        _traditional, simplified, pinyin, definition = parts
        lookup[simplified] = { pinyin: pinyin, definition: definition }
      end
    end

    def krmanik_source
      Source.find_or_create_by(name: "krmanik/HSK-3.0", url: "https://github.com/krmanik/HSK-3.0").tap do |s|
        s.update!(date_accessed: Date.today) if s.date_accessed != Date.today
      end
    end
  end
end
