class DataExportsController < ApplicationController
  def show
    data     = DataExportService.call(user: Current.user)
    filename = "learn_hanzi_export_#{Time.zone.today.iso8601}.json"
    send_data data.to_json, filename:, type: "application/json", disposition: "attachment"
  end
end
