require 'rails_helper'
require 'rake'
require 'tmpdir'

# Run with: bundle exec rspec spec/tasks/dictionary_import_benchmark_spec.rb --tag benchmark
#
# This spec establishes a timing baseline for the CC-CEDICT import pipeline
# using synthetic fixtures of known sizes. It is excluded from the normal
# suite (tagged :benchmark) because it is intentionally slow.
#
# Use it to:
#   1. Record current performance before an optimisation
#   2. Re-run after the optimisation to confirm improvement
#   3. Verify results are consistent (same entry/meaning counts)
RSpec.describe "dictionary_import:cc_cedict performance", :benchmark do
  BENCHMARK_SIZES = [ 20, 200, 2000 ].freeze

  # Generates a valid CC-CEDICT-format file of `count` unique entries.
  # Characters are drawn sequentially from CJK Unified Ideographs Extension A
  # (U+3400–U+4DBF), which are rare enough not to collide with real CC-CEDICT
  # data already in the database.
  def generate_cedict_fixture(count, path)
    File.open(path, "w", encoding: "UTF-8") do |f|
      f.puts "# Benchmark fixture: #{count} synthetic entries"
      count.times do |i|
        char    = (0x3400 + i).chr(Encoding::UTF_8)
        pinyin  = "yi1"
        meaning = "benchmark definition #{i}"
        f.puts "#{char} #{char} [#{pinyin}] /#{meaning}/"
      end
    end
  end

  before(:all) do
    Rake.application.rake_require("tasks/dictionary_import")
    Rake::Task.define_task(:environment)
  end

  after do
    Rake::Task["dictionary_import:cc_cedict"].reenable
  end

  results = {}

  BENCHMARK_SIZES.each do |size|
    describe "with #{size} entries" do
      around do |example|
        Dir.mktmpdir("cedict_benchmark") do |dir|
          @fixture_path = File.join(dir, "cedict_#{size}.u8")
          generate_cedict_fixture(size, @fixture_path)
          example.run
        end
      end

      it "imports all entries and reports elapsed time", :aggregate_failures do
        before_count = DictionaryEntry.count

        output = capture_output do
          Rake::Task["dictionary_import:cc_cedict"].invoke(@fixture_path)
        end

        elapsed_match = output.match(/Completed in ([\d.]+)s/)
        expect(elapsed_match).to be_present, "expected output to include 'Completed in Xs'"

        elapsed  = elapsed_match[1].to_f
        created  = DictionaryEntry.count - before_count

        results[size] = { elapsed: elapsed, created: created }

        expect(created).to eq(size),
          "expected #{size} new DictionaryEntries, got #{created}"

        # Print live so the developer can see timing during the run
        puts format("\n  [benchmark] %4d entries: %.2fs (%.1f entries/s)",
                    size, elapsed, size / elapsed)
      end
    end
  end

  # Summary printed after all sizes have run
  after(:all) do
    next if results.empty?

    puts "\n#{"=" * 50}"
    puts "  CC-CEDICT import benchmark results"
    puts "#{"=" * 50}"
    puts format("  %-10s %10s %15s", "Entries", "Time (s)", "Entries/s")
    puts "  #{"-" * 38}"
    results.sort.each do |size, r|
      puts format("  %-10d %10.2f %15.1f", size, r[:elapsed], size / r[:elapsed])
    end
    puts "#{"=" * 50}"
    puts "  Baseline (no optimisation):  20→0.31s, 200→1.84s,  2000→18.01s (~111/s)"
    puts "  Opt 1 (single txn + pre-load source):          2000→12.68s (~158/s, +40%)"
    puts "  Opt 2 (insert_all batch):                      2000→0.48s  (~4167/s, +37x)"
    puts "#{"=" * 50}\n"
  end
end
