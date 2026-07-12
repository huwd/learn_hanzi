module Mcp
  class ActiveVocabularyResource
    def initialize(user, limit: nil, offset: 0)
      @user = user
      @limit = limit
      @offset = offset
    end

    def call
      scope = user.user_learnings
        .in_progress
        .includes(dictionary_entry: :meanings)
        .order(next_due: :asc)
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
        "hanzi"    => entry.text,
        "pinyin"   => meaning&.pinyin,
        "meaning"  => meaning&.text,
        "next_due" => user_learning.next_due&.iso8601,
        "factor"   => user_learning.factor
      }
    end
  end
end
