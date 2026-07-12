require 'rails_helper'

RSpec.describe Mastery::CoverageTimeline do
  describe ".call" do
    it "returns empty labels and series for no milestones" do
      result = described_class.call(milestones: {}, tiers: [ :established, :emerging ])
      expect(result).to eq(labels: [], series: { established: [], emerging: [] })
    end

    it "buckets each item by the furthest tier reached, weekly, up to end_date" do
      milestones = {
        1 => { established: Time.zone.parse("2026-01-15"), developing: nil, emerging: Time.zone.parse("2026-01-01") },
        2 => { established: nil, developing: Time.zone.parse("2026-01-10"), emerging: Time.zone.parse("2026-01-01") },
        3 => { established: nil, developing: nil, emerging: Time.zone.parse("2026-01-08") }
      }

      result = described_class.call(
        milestones: milestones,
        tiers: [ :established, :developing, :emerging ],
        end_date: Time.zone.parse("2026-01-15")
      )

      expect(result[:labels]).to eq([ "Jan 1", "Jan 8", "Jan 15" ])
      # Jan 1: only item 1 and 2 have touched (emerging), item 3 hasn't yet.
      # Jan 8: item 3 has now touched too; item 2 doesn't cross into developing
      # until Jan 10, so all three still read as emerging at this bucket.
      expect(result[:series][:emerging]).to eq([ 2, 3, 1 ])
      # item 2 crosses into developing on Jan 10 (between Jan 8 and Jan 15 buckets)
      expect(result[:series][:developing]).to eq([ 0, 0, 1 ])
      # item 1 crosses into established on Jan 15
      expect(result[:series][:established]).to eq([ 0, 0, 1 ])
    end

    it "keeps established items established even if a later tier's date is also present" do
      # Established should win over developing/emerging even when all three are set,
      # since tiers are checked most-advanced-first.
      milestones = {
        1 => { established: Time.zone.parse("2026-01-01"), developing: Time.zone.parse("2026-01-01"), emerging: Time.zone.parse("2026-01-01") }
      }

      result = described_class.call(
        milestones: milestones,
        tiers: [ :established, :developing, :emerging ],
        end_date: Time.zone.parse("2026-01-01")
      )

      expect(result[:series][:established]).to eq([ 1 ])
      expect(result[:series][:developing]).to eq([ 0 ])
      expect(result[:series][:emerging]).to eq([ 0 ])
    end

    it "does not count an item before its earliest tier date" do
      milestones = { 1 => { emerging: Time.zone.parse("2026-01-10") } }

      result = described_class.call(
        milestones: milestones,
        tiers: [ :emerging ],
        end_date: Time.zone.parse("2026-01-10")
      )

      expect(result[:labels]).to eq([ "Jan 10" ])
      expect(result[:series][:emerging]).to eq([ 1 ])
    end

    it "counts every item from the same calendar day as an intermediate bucket, not just the earliest time" do
      # Bucket boundaries are generated from the exact `start` timestamp,
      # but labels only show day granularity ("Jan 1"). Without flooring
      # intermediate bucket comparisons to end_of_day, an item touched
      # later the same day as `start` would be missing from the "Jan 1"
      # bucket even though nothing else happened between Jan 1 and Jan 8
      # to explain the gap.
      milestones = {
        1 => { emerging: Time.zone.parse("2026-01-01 08:00") },
        2 => { emerging: Time.zone.parse("2026-01-01 20:00") }
      }

      result = described_class.call(
        milestones: milestones,
        tiers: [ :emerging ],
        end_date: Time.zone.parse("2026-01-15")
      )

      expect(result[:labels].first).to eq("Jan 1")
      expect(result[:series][:emerging].first).to eq(2)
    end

    it "does not duplicate the final bucket when start and end_date share a calendar day" do
      # A new user starting today: start (09:00) and end_date (15:00) are
      # the same day. end_of_day-capping start's bucket lands it exactly
      # on end_date -- the unconditional final push must not add it twice.
      milestones = { 1 => { emerging: Time.zone.parse("2026-01-15 09:00") } }

      result = described_class.call(
        milestones: milestones,
        tiers: [ :emerging ],
        end_date: Time.zone.parse("2026-01-15 15:00")
      )

      expect(result[:labels]).to eq([ "Jan 15" ])
      expect(result[:series][:emerging]).to eq([ 1 ])
    end

    it "caps the final bucket exactly at end_date rather than overshooting" do
      milestones = { 1 => { emerging: Time.zone.parse("2026-01-01") } }

      result = described_class.call(
        milestones: milestones,
        tiers: [ :emerging ],
        end_date: Time.zone.parse("2026-01-10")
      )

      expect(result[:labels].last).to eq("Jan 10")
    end
  end
end
