module Mcp
  class MasteredVocabularyResource
    def initialize(user, limit: nil, offset: 0)
      @user = user
      @limit = limit
      @offset = offset
    end

    def call
      scope = user.user_learnings
        .mastered
        .includes(dictionary_entry: :meanings)
        .order(mastered_at: :desc)
        .offset(@offset)
      scope = scope.limit(@limit) if @limit

      { "vocabulary" => scope.map { |ul| format_entry(ul) } }
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
