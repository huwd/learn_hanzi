class ProgressController < ApplicationController
  DRILLDOWN_BUCKETS = (Mastery::Trajectory::ALL - [ Mastery::Trajectory::NOT_APPLICABLE ]).freeze

  def show
    # Rendered directly (no JSON endpoint/chart library needed) -- a live
    # snapshot over a small population, cheap enough to compute inline.
    # See #391.
    @trajectory = Mastery::TrajectorySnapshot.call(user: Current.user)
  end

  # Drill-down behind a single trajectory tile: which words make it up,
  # ranked by how firmly they exemplify the bucket by default, with an
  # explicit sort/direction override once a column header is clicked.
  # See #391, #400.
  def trajectory
    @bucket = params[:bucket]
    raise ActionController::RoutingError, "Not Found" unless DRILLDOWN_BUCKETS.include?(@bucket)

    # An invalid sort is a bookmarked/hand-edited query string, not a
    # missing resource -- fall back to the bucket's default ranking rather
    # than 500ing (Mastery::TrajectoryEntries itself still raises for any
    # other caller that skips this filtering).
    @sort = params[:sort] if Mastery::TrajectoryEntries::SORTABLE_COLUMNS.include?(params[:sort])
    @direction = params[:direction]

    @result = Mastery::TrajectoryEntries.call(
      user: Current.user,
      bucket: @bucket,
      sort: @sort,
      direction: @direction,
      page: params[:page].presence&.to_i || 1,
      per_page: params[:per_page].presence&.to_i || Mastery::TrajectoryEntries::PER_PAGE
    )
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

    # Union of ids across all three, not just emerging_at's -- every
    # current code path only ever sets first_mastered_at/developing_at
    # alongside review history, but Mastery::Coverage treats
    # first_mastered_at as authoritative regardless of review count, so
    # this must not silently disagree if that invariant ever drifts.
    all_ids = emerging_at.keys | developing_at.keys | established_at.keys
    milestones = all_ids.index_with do |id|
      { established: established_at[id], developing: developing_at[id], emerging: emerging_at[id] }
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

    established_ids = Current.user.user_learnings.where.not(first_mastered_at: nil).pluck(:id)

    # Scoped to touched-or-established words only -- most users have far
    # more Unseen (never-reviewed) words than touched ones (74% in the
    # real dataset behind #391), and an Unseen word can never contribute
    # a character. established_ids is unioned in defensively: every
    # current code path only ever sets first_mastered_at alongside review
    # history, but this must not silently drop a word's characters if
    # that invariant ever drifts.
    words = Current.user.user_learnings
      .where(id: emerging_at.keys | established_ids)
      .joins(:dictionary_entry)
      .pluck(:id, "dictionary_entries.text", :first_mastered_at)

    char_touched = {}
    char_established = {}
    words.each do |id, text, established_at|
      # Falls back to established_at (the best still-known date) when a
      # word's review history is missing -- it must have been touched at
      # or before its own establishment.
      touched_at = emerging_at[id] || established_at
      next unless touched_at

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
