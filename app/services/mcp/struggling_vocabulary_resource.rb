module Mcp
  class StrugglingVocabularyResource
    def initialize(user, limit: nil, offset: 0)
      @user = user
      @limit = limit
      @offset = offset
    end

    def call
      in_progress = user.user_learnings.in_progress

      lapse_counts = ReviewLog
        .where(user_learning: in_progress, ease: 1)
        .group(:user_learning_id)
        .count

      learnings = in_progress
        .includes(dictionary_entry: :meanings)
        .sort_by { |ul| [ -lapse_counts.fetch(ul.id, 0), ul.factor ] }
        .drop(@offset)
      learnings = learnings.first(@limit) if @limit

      { "vocabulary" => learnings.map { |ul| format_entry(ul, lapse_counts.fetch(ul.id, 0)) } }
    end

    private

    attr_reader :user

    def format_entry(user_learning, lapse_count)
      entry   = user_learning.dictionary_entry
      meaning = entry.meanings.first
      {
        "hanzi"       => entry.text,
        "pinyin"      => meaning&.pinyin,
        "meaning"     => meaning&.text,
        "lapse_count" => lapse_count,
        "factor"      => user_learning.factor
      }
    end
  end
end
