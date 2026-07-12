module Mastery
  # Builds a weekly stacked-area timeline from per-item milestone dates.
  # Each item is bucketed into exactly one tier per week -- the FURTHEST
  # tier it had reached as of that week's date, checked in the order
  # `tiers` is given (most-advanced first) so a durable tier like
  # Established always wins over an earlier one even if both dates are
  # present. Feeds the Coverage-over-time chart and the character
  # coverage chart. See #391.
  class CoverageTimeline
    def self.call(milestones:, tiers:, end_date: Time.current)
      new(milestones, tiers, end_date).call
    end

    def initialize(milestones, tiers, end_date)
      @milestones = milestones
      @tiers = tiers
      @end_date = end_date
    end

    def call
      return { labels: [], series: @tiers.index_with { [] } } if @milestones.empty?

      buckets = weekly_buckets
      series = @tiers.index_with { [] }

      buckets.each do |bucket|
        counts = Hash.new(0)
        @milestones.each_value do |item|
          tier = furthest_tier_reached(item, bucket)
          counts[tier] += 1 if tier
        end
        @tiers.each { |t| series[t] << counts[t] }
      end

      { labels: buckets.map { |b| b.strftime("%b %-d") }, series: series }
    end

    private

    def furthest_tier_reached(item, bucket)
      @tiers.find { |t| item[t] && item[t] <= bucket }
    end

    def weekly_buckets
      start = @milestones.values.flat_map(&:values).compact.min
      buckets = []
      d = start
      while d < @end_date
        buckets << d
        d += 7.days
      end
      buckets << @end_date
      buckets
    end
  end
end
