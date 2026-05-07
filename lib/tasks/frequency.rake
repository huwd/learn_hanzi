require_relative "../../app/helpers/import_files_helper"

include ImportFilesHelper

namespace :frequency do
  SUBTLEX_URL = "https://raw.githubusercontent.com/krmanik/HSK-3.0/main/Scripts%20and%20data/SUBTLEX_CH_131210_CE.utf8"

  desc "Download SUBTLEX-CH frequency data"
  task download: :environment do
    file_dir = Rails.root.join("tmp", "frequency")
    file_path = file_dir.join("SUBTLEX_CH_131210_CE.utf8")
    ImportFilesHelper.download_file_to_tmp(SUBTLEX_URL, file_path)
    ImportFilesHelper.confirm_file_presence(File.basename(file_path), file_dir)
  end

  desc "Import SUBTLEX-CH frequency ranks into DictionaryEntry"
  task :import, [ :file_path ] => :environment do |_task, args|
    file_path = args[:file_path] || subtlex_default_path

    unless File.exist?(file_path)
      raise "File not found at #{file_path}. Run `bin/rails frequency:download` first."
    end

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    word_to_freq = parse_subtlex_frequencies(file_path)
    ranked_words = word_to_freq.sort_by { |word, freq| [ -freq, word ] }
    texts = ranked_words.map(&:first)

    entry_id_by_text = DictionaryEntry.where(text: texts).pluck(:text, :id).to_h

    rows = []
    rank = 0
    ranked_words.each do |word, _freq|
      entry_id = entry_id_by_text[word]
      next unless entry_id
      rank += 1
      rows << { id: entry_id, frequency_rank: rank }
    end

    DictionaryEntry.transaction do
      DictionaryEntry.update_all(frequency_rank: nil)
      rows.each_slice(1000) do |slice|
        DictionaryEntry.upsert_all(slice, unique_by: :id, update_only: [ :frequency_rank ])
      end
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    puts "Imported frequency ranks from #{file_path} in #{elapsed.round(2)}s"
    puts "#{word_to_freq.size} unique words parsed"
    puts "#{rows.size} dictionary entries updated"
    puts "#{word_to_freq.size - rows.size} words missing from dictionary"
  end
end

def subtlex_default_path
  Rails.root.join("tmp", "frequency", "SUBTLEX_CH_131210_CE.utf8").to_s
end

def parse_subtlex_frequencies(file_path)
  lines = File.readlines(file_path, chomp: true, encoding: "bom|utf-8")
  header = lines.shift.to_s.split("\t")
  word_index = header.index("Word")
  freq_index = header.index("W.million")

  return {} if word_index.nil? || freq_index.nil?

  lines.each_with_object({}) do |line, acc|
    fields = line.split("\t")
    word = fields[word_index]&.strip
    next if word.blank?

    freq = fields[freq_index].to_s.strip.tr(",", "").to_f
    next if freq <= 0

    acc[word] = [ acc[word].to_f, freq ].max
  end
end
