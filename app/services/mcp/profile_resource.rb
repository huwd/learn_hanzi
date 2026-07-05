module Mcp
  class ProfileResource
    def initialize(user)
      @user = user
    end

    def call
      { summary: summary, hsk_breakdown: hsk_breakdown }
    end

    private

    attr_reader :user

    def summary
      learnings = user.user_learnings
      counts    = learnings.group(:state).count
      total     = counts.values.sum
      {
        "new"       => counts["new"]       || 0,
        "learning"  => counts["learning"]  || 0,
        "mastered"  => counts["mastered"]  || 0,
        "suspended" => counts["suspended"] || 0,
        "total"     => total
      }
    end

    def hsk_breakdown
      root = Tag.includes(children: :children).find_by(name: "HSK", parent_id: nil)
      return [] unless root

      root.children.sort_by(&:name).map do |version|
        levels     = version.children.sort_by(&:name)
        level_data = build_level_data(levels)
        { "version" => version.name, "levels" => levels.map { |l| level_data[l.id] } }
      end
    end

    def build_level_data(level_tags)
      return {} if level_tags.empty?

      tag_ids = level_tags.map(&:id)
      state_counts = UserLearning
        .where(user: user)
        .joins(dictionary_entry: :dictionary_entry_tags)
        .where(dictionary_entry_tags: { tag_id: tag_ids })
        .group("dictionary_entry_tags.tag_id", :state)
        .count

      level_tags.each_with_object({}) do |tag, result|
        result[tag.id] = {
          "name"      => tag.name,
          "mastered"  => state_counts[[ tag.id, "mastered"  ]] || 0,
          "learning"  => state_counts[[ tag.id, "learning"  ]] || 0,
          "new"       => state_counts[[ tag.id, "new"       ]] || 0,
          "suspended" => state_counts[[ tag.id, "suspended" ]] || 0
        }
      end
    end
  end
end
