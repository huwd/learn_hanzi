class LearningAdvisor
  Result = Data.define(
    :profile,
    :narrative,
    :recommended_size,
    :recommended_new_cap,
    :leech_warning,
    :first_90_days,
    :signals
  )

  LIMITS = {
    empty:       { size: 20, new_cap: 5  },
    healthy:     { size: 20, new_cap: 5  },
    catching_up: { size: 30, new_cap: 0  },
    lapsed:      { size: 15, new_cap: 0  },
    overloaded:  { size: 20, new_cap: 10 },
    cramming:    { size: 15, new_cap: 5  },
    maintenance: { size: 20, new_cap: 5  }
  }.freeze

  NARRATIVES = {
    empty:       "Your learning record is empty. Import your Anki collection to pick up where you left off, or start fresh with the vocabulary browser.",
    lapsed:      "Welcome back! It's been a while since your last session. Some cards may have faded — that's normal and the algorithm expects it. Start with a short session today.",
    maintenance: "Your deck is stable and well-maintained. Most of your cards are deeply learned. Keep up the light daily check-ins to lock in those gains.",
    overloaded:  "You're adding new cards faster than you can consolidate them — the most common cause of SRS burnout. The queue will keep growing for another two weeks even if you stop adding now. Consider pausing new cards until the backlog clears.",
    cramming:    "Your sessions are intense but infrequent. Spaced repetition works best as a daily habit — even 10 minutes beats one long session a week. Try a modest daily target instead.",
    catching_up: "You have a backlog building up. Don't try to clear it all at once. Focus on your overdue cards first and pause new cards until you're caught up.",
    healthy:     "You're in a good rhythm. Keep it up!"
  }.freeze

  def self.classify(user:)
    new(user).classify
  end

  def initialize(user)
    @user = user
  end

  def classify
    signals  = compute_signals
    profile  = classify_profile(signals)
    limits   = LIMITS.fetch(profile)

    Result.new(
      profile:             profile,
      narrative:           build_narrative(profile, signals),
      recommended_size:    limits[:size],
      recommended_new_cap: limits[:new_cap],
      leech_warning:       signals[:leech_count] > 0,
      first_90_days:       signals[:first_90_days],
      signals:             signals
    )
  end

  private

  # ---------------------------------------------------------------------------
  # Signal computation
  # ---------------------------------------------------------------------------

  def compute_signals
    ul = @user.user_learnings
    rl = review_logs_scope

    total_count    = ul.count
    active_count   = ul.where(state: %w[learning mastered]).count
    mastered_count = ul.mastered.count
    overdue_count  = ul.overdue_learning.count + ul.due_mastered.count
    total_logs     = rl.count

    daily_14d      = daily_counts(rl, days: 14)
    avg_daily      = daily_14d.empty? ? 0.0 : daily_14d.sum.to_f / 14

    days_since     = days_since_last_review(rl)
    backlog_ratio  = avg_daily > 0 ? overdue_count.to_f / avg_daily : (overdue_count > 0 ? Float::INFINITY : 0.0)
    mastery_pct    = active_count > 0 ? mastered_count.to_f / active_count : 0.0

    active_days_14 = daily_14d.size
    max_daily      = daily_14d.max || 0
    cramming_ratio = avg_daily > 0 ? max_daily.to_f / avg_daily : 0.0

    new_7day_avg   = new_cards_per_day(rl, days: 7)
    leech_count    = compute_leech_count(rl)
    first_90       = first_90_days?(rl)

    {
      total_count:     total_count,
      active_count:    active_count,
      mastered_count:  mastered_count,
      overdue_count:   overdue_count,
      total_logs:      total_logs,
      days_since:      days_since,
      avg_daily:       avg_daily,
      new_7day_avg:    new_7day_avg,
      backlog_ratio:   backlog_ratio,
      mastery_pct:     mastery_pct,
      active_days_14d: active_days_14,
      max_daily:       max_daily,
      cramming_ratio:  cramming_ratio,
      leech_count:     leech_count,
      first_90_days:   first_90
    }
  end

  def review_logs_scope
    @review_logs_scope ||=
      ReviewLog.joins(:user_learning)
               .where(user_learnings: { user_id: @user.id })
  end

  def daily_counts(rl, days:)
    rl.where("review_logs.created_at >= ?", days.days.ago)
      .group("DATE(review_logs.created_at)")
      .count
      .values
  end

  def days_since_last_review(rl)
    last = rl.maximum(:created_at)
    last ? (Time.current - last) / 1.day : nil
  end

  # Count distinct user_learnings whose first-ever review_log was in the last `days` days
  def new_cards_per_day(rl, days:)
    count = rl.group(:user_learning_id)
              .having("MIN(review_logs.created_at) >= ?", days.days.ago)
              .count
              .size
    count.to_f / days
  end

  # Cards where 4+ reviews were rated 1 or 2 (Again / Hard)
  def compute_leech_count(rl)
    rl.where(ease: [ 1, 2 ])
      .group(:user_learning_id)
      .having("COUNT(*) >= 4")
      .count
      .size
  end

  def first_90_days?(rl)
    first = rl.minimum(:created_at)
    first.nil? || first >= 90.days.ago
  end

  # ---------------------------------------------------------------------------
  # Profile classification
  # ---------------------------------------------------------------------------

  def classify_profile(s)
    return :empty       if s[:total_count] == 0
    return :lapsed      if s[:total_logs] == 0 || s[:days_since].nil? || s[:days_since] > 7
    return :maintenance if maintenance?(s)
    return :overloaded  if s[:new_7day_avg] > 25 && s[:backlog_ratio] > 1
    return :cramming    if s[:cramming_ratio] > 3 && s[:active_days_14d] < 5 && s[:max_daily] >= 20
    return :catching_up if s[:backlog_ratio] > 1
    :healthy
  end

  def maintenance?(s)
    s[:mastery_pct] > 0.8 &&
      s[:new_7day_avg] < 5 &&
      s[:backlog_ratio] < 0.5 &&
      s[:days_since] && s[:days_since] <= 3
  end

  # ---------------------------------------------------------------------------
  # Narrative
  # ---------------------------------------------------------------------------

  def build_narrative(profile, signals)
    base = NARRATIVES.fetch(profile)
    if signals[:first_90_days] && profile != :empty
      "#{base} You're still building the habit — consistency matters more than volume right now."
    else
      base
    end
  end
end
