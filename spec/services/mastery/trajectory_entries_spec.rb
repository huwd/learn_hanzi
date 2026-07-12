require "rails_helper"

RSpec.describe Mastery::TrajectoryEntries do
  include QueryCounter

  let(:user) { create(:user) }
  let(:threshold) { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT }

  def graduate!(ul)
    create(:review_log, user_learning: ul, ease: 3)
    ul.update!(state: "mastered")
  end

  def word(text:)
    entry = create(:dictionary_entry, text: text)
    entry.meanings.first.update!(pinyin: "#{text}-pinyin", text: "#{text}-meaning")
    entry
  end

  def stable_established(text: "established_word")
    ul = create(:user_learning, user: user, state: "learning", dictionary_entry: word(text: text))
    graduate!(ul)
    ul
  end

  def chronic(text: "chronic_word", graduations: 2)
    ul = create(:user_learning, user: user, state: "learning", dictionary_entry: word(text: text))
    graduations.times do
      graduate!(ul)
      ul.update!(state: "learning") unless ul.graduation_count >= graduations
    end
    ul
  end

  def recovering(text: "recovering_word")
    ul = create(:user_learning, user: user, state: "learning", dictionary_entry: word(text: text))
    graduate!(ul)
    ul.update!(state: "learning")
    ul
  end

  def stalled(text: "stalled_word")
    ul = create(:user_learning, user: user, state: "learning", dictionary_entry: word(text: text))
    threshold.times { create(:review_log, user_learning: ul, ease: 1) }
    ul
  end

  def stable_developing(text: "developing_word")
    ul = create(:user_learning, user: user, state: "learning", dictionary_entry: word(text: text))
    (threshold - 1).times { create(:review_log, user_learning: ul, ease: 3) }
    create(:review_log, user_learning: ul, ease: 4)
    ul
  end

  describe ".call" do
    it "returns entries in Word/Meaning/Ease/Graduations/Since/Next due shape" do
      ul = stable_established

      result = described_class.call(user: user, bucket: Mastery::Trajectory::STABLE)
      entry = result.entries.first

      expect(entry.text).to eq("established_word")
      expect(entry.pinyin).to eq("established_word-pinyin")
      expect(entry.meaning).to eq("established_word-meaning")
      expect(entry.factor).to eq(ul.factor)
      expect(entry.graduation_count).to eq(1)
      expect(entry.since).to be_present
      expect(entry.coverage).to eq(Mastery::Coverage::ESTABLISHED)
    end

    it "scopes Chronic to Established words only" do
      chronic_ul = chronic
      stalled # a Developing word -- must never show up under Chronic

      result = described_class.call(user: user, bucket: Mastery::Trajectory::CHRONIC)

      expect(result.entries.map(&:id)).to eq([ chronic_ul.id ])
    end

    it "scopes Stalled to Developing words only" do
      stalled_ul = stalled
      chronic # an Established word -- must never show up under Stalled

      result = described_class.call(user: user, bucket: Mastery::Trajectory::STALLED)

      expect(result.entries.map(&:id)).to eq([ stalled_ul.id ])
    end

    it "scopes Recovering to Established words only" do
      recovering_ul = recovering
      stalled # a Developing word -- must never show up under Recovering

      result = described_class.call(user: user, bucket: Mastery::Trajectory::RECOVERING)

      expect(result.entries.map(&:id)).to eq([ recovering_ul.id ])
    end

    it "spans both populations for Stable, Established first by default" do
      developing_ul = stable_developing
      established_ul = stable_established

      result = described_class.call(user: user, bucket: Mastery::Trajectory::STABLE)

      expect(result.entries.map(&:id)).to eq([ established_ul.id, developing_ul.id ])
      expect(result.entries.map(&:coverage)).to eq([
        Mastery::Coverage::ESTABLISHED,
        Mastery::Coverage::DEVELOPING
      ])
    end

    it "defaults Chronic to most-relapsed first" do
      twice = chronic(text: "twice", graduations: 2)
      thrice = chronic(text: "thrice", graduations: 3)

      result = described_class.call(user: user, bucket: Mastery::Trajectory::CHRONIC)

      expect(result.entries.map(&:id)).to eq([ thrice.id, twice.id ])
    end

    it "only returns the given user's words" do
      other_user = create(:user)
      other_ul = create(:user_learning, user: other_user, state: "learning", dictionary_entry: word(text: "other"))
      graduate!(other_ul)

      result = described_class.call(user: user, bucket: Mastery::Trajectory::STABLE)

      expect(result.entries).to be_empty
      expect(result.total).to eq(0)
    end

    it "sorts explicitly by word ascending when requested, across the whole bucket" do
      stable_developing(text: "zzz_developing")
      stable_established(text: "aaa_established")

      result = described_class.call(user: user, bucket: Mastery::Trajectory::STABLE, sort: "word", direction: "asc")

      expect(result.entries.map(&:text)).to eq([ "aaa_established", "zzz_developing" ])
    end

    it "sorts explicitly by graduations ascending when requested" do
      low = chronic(text: "low", graduations: 2)
      high = chronic(text: "high", graduations: 4)

      result = described_class.call(user: user, bucket: Mastery::Trajectory::CHRONIC, sort: "graduations", direction: "asc")

      expect(result.entries.map(&:id)).to eq([ low.id, high.id ])
    end

    it "rejects an unsupported sort column" do
      expect {
        described_class.call(user: user, bucket: Mastery::Trajectory::STABLE, sort: "nonsense", direction: "asc")
      }.to raise_error(ArgumentError)
    end

    it "paginates results" do
      5.times { |n| stable_established(text: "word_#{n}") }

      result = described_class.call(user: user, bucket: Mastery::Trajectory::STABLE, sort: "word", direction: "asc", page: 1, per_page: 2)
      expect(result.entries.map(&:text)).to eq([ "word_0", "word_1" ])
      expect(result.total).to eq(5)
      expect(result.page).to eq(1)
      expect(result.per_page).to eq(2)

      page_two = described_class.call(user: user, bucket: Mastery::Trajectory::STABLE, sort: "word", direction: "asc", page: 2, per_page: 2)
      expect(page_two.entries.map(&:text)).to eq([ "word_2", "word_3" ])
    end

    it "returns zeroed results when there is nothing to classify" do
      result = described_class.call(user: user, bucket: Mastery::Trajectory::STABLE)

      expect(result.entries).to eq([])
      expect(result.total).to eq(0)
    end

    it "keeps the query count bounded by page size, not bucket size" do
      # Hydration (dictionary_entry/meanings) should only touch the current
      # page's rows, not the whole bucket -- mirrors TrajectorySnapshot's
      # existing bounded-query guarantee.
      5.times { |n| stable_established(text: "small_#{n}") }
      small_count = count_queries do
        described_class.call(user: user, bucket: Mastery::Trajectory::STABLE, page: 1, per_page: 2)
      end

      15.times { |n| stable_established(text: "big_#{n}") }
      big_count = count_queries do
        described_class.call(user: user, bucket: Mastery::Trajectory::STABLE, page: 1, per_page: 2)
      end

      expect(big_count).to eq(small_count)
    end
  end
end
