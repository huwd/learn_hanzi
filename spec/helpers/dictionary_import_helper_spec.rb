require 'rails_helper'

include DictionaryImportHelper

RSpec.describe "find_or_create_cc_cedict_source" do
  it "creates a new source if it doesn't exist" do
    expect {
      find_or_create_cc_cedict_source("CC-CEDICT", "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
    }.to change(Source, :count).by(1)

    source = Source.find_by(name: "CC-CEDICT")
    expect(source).to be_present
    expect(source.url).to eq("https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
    expect(source.date_accessed).to eq(Date.today)
  end

  it "updates the date_accessed for an existing source" do
    existing_source = Source.create!(
      name: "CC-CEDICT",
      url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip",
      date_accessed: Date.yesterday
    )

    find_or_create_cc_cedict_source("CC-CEDICT", "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
    existing_source.reload

    expect(existing_source.date_accessed).to eq(Date.today)
  end
end
