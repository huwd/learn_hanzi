class AddTelemetryEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :telemetry_enabled, :boolean, default: false, null: false
  end
end
