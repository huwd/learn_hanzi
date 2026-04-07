class DataImportService
  SUPPORTED_VERSIONS = [ 1 ].freeze

  class UnsupportedVersionError < StandardError; end

  def self.call(user:, data:)
    new(user:, data:).call
  end

  def initialize(user:, data:)
    @user = user
    @data = data
  end

  def call
    validate_version!

    learnings_upserted    = 0
    review_logs_inserted  = 0

    @data["user_learnings"].each do |ul_data|
      entry = DictionaryEntry.find_by(text: ul_data["character"])
      next unless entry

      ul, updated = upsert_user_learning(entry, ul_data)
      learnings_upserted += 1 if updated

      rl_rows = build_review_log_rows(ul, ul_data["review_logs"])
      ReviewLog.insert_all(rl_rows, unique_by: [ :user_learning_id, :source_export_id ]) if rl_rows.any?
      review_logs_inserted += rl_rows.size
    end

    { learnings_upserted:, review_logs_inserted: }
  end

  private

  def validate_version!
    version = @data["version"]
    return if SUPPORTED_VERSIONS.include?(version)

    raise UnsupportedVersionError, "Unsupported export format version: #{version}"
  end

  def upsert_user_learning(entry, ul_data)
    export_updated_at = Time.zone.parse(ul_data["updated_at"])
    ul = @user.user_learnings.find_or_initialize_by(dictionary_entry: entry)
    should_update = ul.new_record? || ul.updated_at < export_updated_at

    if should_update
      ul.assign_attributes(
        state:         ul_data["state"],
        next_due:      ul_data["next_due"] ? Time.zone.parse(ul_data["next_due"]) : nil,
        last_interval: ul_data["last_interval"],
        factor:        ul_data["factor"]
      )
      ul.save!
    end

    [ ul, should_update ]
  end

  def build_review_log_rows(ul, review_logs_data)
    now = Time.current
    review_logs_data.map do |rl_data|
      {
        user_learning_id: ul.id,
        ease:             rl_data["ease"],
        interval:         rl_data["interval"],
        time_spent:       rl_data["time_spent"],
        factor:           rl_data["factor"],
        log_type:         rl_data["log_type"],
        time:             rl_data["time"],
        source_export_id: rl_data["id"],
        created_at:       Time.zone.parse(rl_data["created_at"]),
        updated_at:       now
      }
    end
  end
end
