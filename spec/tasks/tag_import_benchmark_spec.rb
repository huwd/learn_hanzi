require 'rails_helper'
require 'rake'
require 'tmpdir'

# Run with: bundle exec rspec spec/tasks/tag_import_benchmark_spec.rb --tag benchmark
#
# Measures the HSK tag import pipeline across fixture sizes.
# Excluded from the normal suite via the :benchmark tag.
RSpec.describe "tag_import:hsk_2 performance", :benchmark do
  BENCHMARK_SIZES = [ 100, 1_000, 5_000 ].freeze

  def generate_hsk_fixture(count, path)
    entries = count.times.map do |i|
      char = (0x3400 + i).chr(Encoding::UTF_8)
      { "s" => char, "r" => "一", "q" => i, "p" => [ "n" ],
        "f" => [ { "t" => char, "i" => { "y" => "yi1", "n" => "yi1" }, "m" => [ "benchmark #{i}" ], "c" => [] } ] }
    end
    File.write(path, JSON.generate(entries))
  end

  before(:all) do
    Rake.application.rake_require("tasks/tag_import")
    Rake::Task.define_task(:environment)
  end

  after do
    Rake::Task["tag_import:hsk_2"].reenable
  end

  results = {}

  BENCHMARK_SIZES.each do |size|
    describe "with #{size} entries" do
      around do |example|
        Dir.mktmpdir("hsk_benchmark") do |dir|
          @fixture_dir = dir
          generate_hsk_fixture(size, File.join(dir, "1.min.json"))

          # Pre-create matching DictionaryEntries so tag association can succeed
          size.times do |i|
            char = (0x3400 + i).chr(Encoding::UTF_8)
            de = DictionaryEntry.find_or_initialize_by(text: char)
            de.meanings.build(text: "benchmark #{i}", language: "en", pinyin: "yī",
                              source: Source.find_or_create_by!(name: "benchmark"))
            de.save!
          end

          example.run
        end
      end

      it "imports all entries and reports elapsed time", :aggregate_failures do
        before_count = DictionaryEntryTag.count

        output = capture_output do
          Rake::Task["tag_import:hsk_2"].invoke(@fixture_dir)
        end

        elapsed_match = output.match(/Completed in ([\d.]+)s/)
        expect(elapsed_match).to be_present, "expected output to include 'Completed in Xs'"

        elapsed = elapsed_match[1].to_f
        created = DictionaryEntryTag.count - before_count
        results[size] = { elapsed: elapsed, created: created }

        expect(created).to eq(size), "expected #{size} new DictionaryEntryTags, got #{created}"

        puts format("\n  [benchmark] %5d entries: %.2fs (%.0f entries/s)",
                    size, elapsed, size / elapsed)
      end
    end
  end

  after(:all) do
    next if results.empty?

    puts "\n#{"=" * 50}"
    puts "  HSK tag import benchmark results"
    puts "#{"=" * 50}"
    puts format("  %-10s %10s %15s", "Entries", "Time (s)", "Entries/s")
    puts "  #{"-" * 38}"
    results.sort.each do |size, r|
      puts format("  %-10d %10.2f %15.0f", size, r[:elapsed], size / r[:elapsed])
    end
    puts "#{"=" * 50}\n"
  end
end
