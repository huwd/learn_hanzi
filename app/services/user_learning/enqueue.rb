class UserLearning::Enqueue
  def self.call(user:, tag: nil)
    new(user, tag).call
  end

  def initialize(user, tag)
    @user = user
    @tag  = tag
  end

  def call
    return unless @tag

    existing_entry_ids = @user.user_learnings.pluck(:dictionary_entry_id)
    unlearned = DictionaryEntry
                  .joins(:dictionary_entry_tags)
                  .where(dictionary_entry_tags: { tag_id: @tag.subtree_ids })
                  .where.not(id: existing_entry_ids)
                  .distinct

    unlearned.find_each do |entry|
      @user.user_learnings.create!(dictionary_entry: entry, state: "new")
    end
  end
end
