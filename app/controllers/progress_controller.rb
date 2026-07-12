class ProgressController < ApplicationController
  def show
    # Rendered directly (no JSON endpoint/chart library needed) -- a live
    # snapshot over a small population, cheap enough to compute inline.
    # See #391.
    @trajectory = Mastery::TrajectorySnapshot.call(user: Current.user)
  end

  # Weekly stacked-area trend: each word is bucketed by the furthest
  # Coverage tier it had reached as of that week (Established durable via
  # first_mastered_at, Developing via developing_at, Emerging via first
  # review date) -- genuinely monotonic in total, replacing the old
  # single volatile "mastered" line. See #391.
  def coverage_chart_data
    emerging_at = ReviewLog
      .joins(:user_learning)
      .where(user_learnings: { user: Current.user })
      .group(:user_learning_id)
      .minimum(:created_at)

    developing_at = Current.user.user_learnings.where.not(developing_at: nil).pluck(:id, :developing_at).to_h
    established_at = Current.user.user_learnings.where.not(first_mastered_at: nil).pluck(:id, :first_mastered_at).to_h

    milestones = emerging_at.each_with_object({}) do |(id, t), memo|
      memo[id] = { established: established_at[id], developing: developing_at[id], emerging: t }
    end

    timeline = Mastery::CoverageTimeline.call(
      milestones: milestones,
      tiers: [ :established, :developing, :emerging ]
    )

    render json: {
      labels: timeline[:labels],
      series: [
        { label: "Established", color: "rgb(67, 56, 202)",   values: timeline[:series][:established] },
        { label: "Developing",  color: "rgb(99, 102, 241)",  values: timeline[:series][:developing] },
        { label: "Emerging",    color: "rgb(165, 180, 252)", values: timeline[:series][:emerging] }
      ]
    }
  end

  # Two tiers, not four: a character isn't reviewed directly, and the real
  # data behind #391 showed no natural Emerging/Developing split at the
  # character level (median distinct-word-touch-count at establishment is
  # 1). A character is Established the moment any containing word
  # graduates; Touched from its earliest containing word's first review.
  # See #391, app/services/mastery/README.md.
  def character_chart_data
    emerging_at = ReviewLog
      .joins(:user_learning)
      .where(user_learnings: { user: Current.user })
      .group(:user_learning_id)
      .minimum(:created_at)

    # Scoped to touched words only -- most users have far more Unseen
    # (never-reviewed) words than touched ones (74% in the real dataset
    # behind #391), and an Unseen word can never contribute a character.
    words = Current.user.user_learnings
      .where(id: emerging_at.keys)
      .joins(:dictionary_entry)
      .pluck(:id, "dictionary_entries.text", :first_mastered_at)

    char_touched = {}
    char_established = {}
    words.each do |id, text, established_at|
      touched_at = emerging_at[id]

      text.chars.each do |char|
        char_touched[char] = touched_at if char_touched[char].nil? || touched_at < char_touched[char]
        next unless established_at

        char_established[char] = established_at if char_established[char].nil? || established_at < char_established[char]
      end
    end

    milestones = char_touched.each_with_object({}) do |(char, touched_at), memo|
      memo[char] = { established: char_established[char], touched: touched_at }
    end

    timeline = Mastery::CoverageTimeline.call(
      milestones: milestones,
      tiers: [ :established, :touched ]
    )

    render json: {
      labels: timeline[:labels],
      series: [
        { label: "Established", color: "rgb(15, 118, 110)",  values: timeline[:series][:established] },
        { label: "Touched",     color: "rgb(94, 234, 212)",  values: timeline[:series][:touched] }
      ]
    }
  end
end
