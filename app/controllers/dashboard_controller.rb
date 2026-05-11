class DashboardController < ApplicationController
  def index
    user_learnings = Current.user.user_learnings

    @no_data = user_learnings.none?
    @advice  = @no_data ? nil : LearningAdvisor.classify(user: Current.user)
    @settings_nudge = @advice && (
      @advice.recommended_size != Current.user.session_size ||
      @advice.recommended_new_cap != Current.user.new_cards_per_session
    )

    @learning_due = user_learnings.overdue_learning.count
    @review_due   = user_learnings.due_mastered.count

    @state_counts = {
      new:      user_learnings.new_learnings.count,
      learning: user_learnings.in_progress.count,
      mastered: user_learnings.mastered.count
    }

    @new_cards_count = @state_counts[:new]
    @next_hsk_milestone = build_next_hsk_milestone
    @mastered_characters_count = count_mastered_characters(user_learnings)

    @vocabulary_sections = build_vocabulary_sections
  end

  private

  def build_vocabulary_sections
    hsk_versions.map do |version_tag|
      level_tags  = version_tag.children.sort_by(&:name)
      level_stats = hsk_level_stats.slice(*level_tags.map(&:id))

      aggregate = aggregate_stats(level_stats.values)

      { version: version_tag, levels: level_tags.map { |t| { tag: t, stats: level_stats[t.id] } }, aggregate: aggregate }
    end
  end

  def build_level_tag_stats(level_tags)
    tag_ids = level_tags.map(&:id)

    entry_counts = DictionaryEntryTag
      .where(tag_id: tag_ids)
      .group(:tag_id)
      .count

    state_counts = UserLearning
      .where(user: Current.user)
      .joins(dictionary_entry: :dictionary_entry_tags)
      .where(dictionary_entry_tags: { tag_id: tag_ids })
      .group("dictionary_entry_tags.tag_id", :state)
      .count

    level_tags.each_with_object({}) do |tag, result|
      total     = entry_counts[tag.id] || 0
      mastered  = state_counts[[ tag.id, "mastered" ]]  || 0
      learning  = state_counts[[ tag.id, "learning" ]]  || 0
      new_count = state_counts[[ tag.id, "new" ]]        || 0
      suspended = state_counts[[ tag.id, "suspended" ]]  || 0
      started   = mastered + learning + new_count + suspended

      result[tag.id] = {
        total:       total,
        mastered:    mastered,
        learning:    learning,
        new_count:   new_count,
        not_started: [ total - started, 0 ].max
      }
    end
  end

  def hsk_level_stats
    @hsk_level_stats ||= begin
      level_tags = hsk_versions.flat_map(&:children)
      level_tags.empty? ? {} : build_level_tag_stats(level_tags)
    end
  end

  def hsk_root
    @hsk_root ||= Tag.includes(children: :children).find_by(name: "HSK", parent_id: nil)
  end

  def hsk_versions
    @hsk_versions ||= hsk_root ? hsk_root.children.sort_by(&:name) : []
  end

  def aggregate_stats(stats_list)
    %i[total mastered learning new_count not_started].each_with_object({}) do |key, agg|
      agg[key] = stats_list.sum { |s| s[key] }
    end
  end

  def build_next_hsk_milestone
    hsk3 = hsk_versions.find { |tag| tag.name == "HSK 3.0" }
    return nil unless hsk3

    levels = hsk3.children.sort_by { |tag| hsk_level_sort_key(tag.name) }
    return nil if levels.empty?

    level_stats = hsk_level_stats.slice(*levels.map(&:id))
    return nil if level_stats.values.all? { |stats| stats[:total].zero? }

    next_level = levels.find do |level|
      stats = level_stats[level.id]
      total = stats[:total]
      next false if total.zero?

      mastered = stats[:mastered]
      mastered < total
    end

    return { complete: true } unless next_level

    stats = level_stats[next_level.id]
    total = stats[:total]
    mastered = stats[:mastered]

    {
      complete: false,
      tier_name: next_level.name,
      remaining_words: [ total - mastered, 0 ].max
    }
  end

  def hsk_level_sort_key(name)
    return [ 9_999, 0 ] if name.include?("7-9")

    number = name[/\d+/]&.to_i
    [ number || 9_998, 0 ]
  end

  def count_mastered_characters(user_learnings)
    texts = user_learnings
      .mastered
      .joins(:dictionary_entry)
      .distinct
      .pluck("dictionary_entries.text")

    seen = {}
    texts.each do |text|
      text.to_s.each_char { |char| seen[char] = true }
    end

    seen.size
  end
end
