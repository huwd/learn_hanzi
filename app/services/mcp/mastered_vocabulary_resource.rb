module Mcp
  class MasteredVocabularyResource
    def initialize(user)
      @user = user
    end

    def call
      vocabulary = user.user_learnings
        .mastered
        .includes(dictionary_entry: :meanings)
        .order(mastered_at: :desc)
        .map { |ul| format_entry(ul) }

      { "vocabulary" => vocabulary }
    end

    private

    attr_reader :user

    def format_entry(user_learning)
      entry   = user_learning.dictionary_entry
      meaning = entry.meanings.first
      {
        "hanzi"       => entry.text,
        "pinyin"      => meaning&.pinyin,
        "meaning"     => meaning&.text,
        "mastered_at" => user_learning.mastered_at&.iso8601
      }
    end
  end
end
