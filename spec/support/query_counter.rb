module QueryCounter
  # Returns the number of data-access SQL statements fired within the given block.
  # Filters out SQLite infrastructure: PRAGMA, SAVEPOINT, RELEASE, BEGIN, COMMIT,
  # ROLLBACK, schema introspection, and EXPLAIN so counts reflect actual queries.
  IGNORED_PREFIXES = %w[PRAGMA SAVEPOINT RELEASE ROLLBACK BEGIN COMMIT].freeze

  def count_queries(&block)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name].in?(%w[SCHEMA EXPLAIN])
      sql = payload[:sql].to_s.lstrip.upcase
      next if IGNORED_PREFIXES.any? { |prefix| sql.start_with?(prefix) }

      count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
