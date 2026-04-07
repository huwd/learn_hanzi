class DataExportService
  CURRENT_VERSION = 1

  def self.call(user:)
    new(user:).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    {
      version: CURRENT_VERSION,
      exported_at: Time.current.iso8601,
      user_learnings: export_user_learnings
    }
  end

  private

  def export_user_learnings
    @user.user_learnings
         .includes(:dictionary_entry, :review_logs)
         .joins(:dictionary_entry)
         .order("dictionary_entries.text ASC")
         .map do |ul|
      {
        character:     ul.dictionary_entry.text,
        state:         ul.state,
        next_due:      ul.next_due&.iso8601(3),
        last_interval: ul.last_interval,
        factor:        ul.factor,
        created_at:    ul.created_at.iso8601,
        updated_at:    ul.updated_at.iso8601,
        review_logs:   ul.review_logs.sort_by { |rl| [ rl.created_at, rl.id ] }.map { |rl| export_review_log(rl) }
      }
    end
  end

  def export_review_log(rl)
    {
      id:          rl.source_export_id || rl.id,
      ease:        rl.ease,
      interval:    rl.interval,
      time_spent:  rl.time_spent,
      factor:      rl.factor,
      log_type:    rl.log_type,
      time:        rl.time,
      created_at:  rl.created_at.iso8601
    }
  end
end
