class ProgressController < ApplicationController
  def show
  end

  def chart_data
    new_per_day = Current.user.user_learnings
      .group("date(created_at)")
      .order("date(created_at)")
      .count

    mastered_per_day = Current.user.user_learnings
      .where.not(mastered_at: nil)
      .group("date(mastered_at)")
      .order("date(mastered_at)")
      .count

    all_dates = (new_per_day.keys + mastered_per_day.keys).uniq.sort

    cumulative_seen = 0
    cumulative_mastered = 0

    data = all_dates.map do |date|
      cumulative_seen += new_per_day[date] || 0
      cumulative_mastered += mastered_per_day[date] || 0
      {
        date: date.to_s,
        seen: cumulative_seen,
        mastered: cumulative_mastered,
        learning: cumulative_seen - cumulative_mastered
      }
    end

    render json: data
  end
end
