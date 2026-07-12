class ProgressController < ApplicationController
  def show
  end

  def chart_data
    first_review_by_card = ReviewLog
      .joins(:user_learning)
      .where(user_learnings: { user: Current.user })
      .group(:user_learning_id)
      .minimum("review_logs.created_at")

    learning_per_day = first_review_by_card.values
      .group_by { |dt| dt.to_date.to_s }
      .transform_values(&:count)

    # Keyed on first_mastered_at (durable, never cleared on lapse) rather
    # than state/mastered_at, so a later lapse doesn't retroactively lower
    # this count at every date since the original mastery. See #391.
    mastered_per_day = Current.user.user_learnings
      .where.not(first_mastered_at: nil)
      .group("date(first_mastered_at)")
      .order("date(first_mastered_at)")
      .count

    all_dates = (learning_per_day.keys + mastered_per_day.keys).uniq.sort

    cumulative_learning = 0
    cumulative_mastered = 0
    mastered_values = []
    in_progress_values = []

    all_dates.each do |date|
      cumulative_learning += learning_per_day[date] || 0
      cumulative_mastered += mastered_per_day[date] || 0
      mastered_values << cumulative_mastered
      in_progress_values << [ cumulative_learning - cumulative_mastered, 0 ].max
    end

    render json: {
      labels: all_dates,
      series: [
        { label: "Mastered",     color: "rgb(34, 197, 94)",  values: mastered_values },
        { label: "In progress",  color: "rgb(245, 158, 11)", values: in_progress_values }
      ]
    }
  end

  def character_chart_data
    # Keyed on first_mastered_at (durable, never cleared on lapse) rather
    # than state/mastered_at, so a later lapse doesn't drop the word's
    # characters out of this count. See #391.
    mastered = Current.user.user_learnings
      .where.not(first_mastered_at: nil)
      .joins(:dictionary_entry)
      .select("dictionary_entries.text, user_learnings.first_mastered_at")

    # For each character find the earliest date it appeared in a mastered word
    char_first_mastered = {}
    mastered.each do |ul|
      date = ul.first_mastered_at.to_date.to_s
      ul.text.chars.each do |char|
        char_first_mastered[char] = date if char_first_mastered[char].nil? || date < char_first_mastered[char]
      end
    end

    per_day = char_first_mastered.values.tally
    all_dates = per_day.keys.sort

    cumulative = 0
    values = all_dates.map { |date| cumulative += per_day[date]; cumulative }

    render json: {
      labels: all_dates,
      series: [
        { label: "Characters mastered", color: "rgb(99, 102, 241)", values: values }
      ]
    }
  end
end
