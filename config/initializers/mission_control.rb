# Use the existing session-based admin authentication rather than HTTP Basic.
MissionControl::Jobs.base_controller_class = "Admin::BaseController"
MissionControl::Jobs.http_basic_auth_enabled = false
