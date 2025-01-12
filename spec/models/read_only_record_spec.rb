require 'rails_helper'

RSpec.describe ReadOnlyRecord, type: :model do
  class TestReadOnlyRecord < ReadOnlyRecord
    self.table_name = 'users' #  Have to use a real table name or migrate a dummy one
  end

  before do
    # Stub these so ActiveRecord won’t try to find or interact with a real table
    allow(TestReadOnlyRecord).to receive(:columns).and_return([])
    allow(TestReadOnlyRecord).to receive(:columns_hash).and_return({})
    allow(TestReadOnlyRecord).to receive(:table_exists?).and_return(false)
  end

  describe "#readonly?" do
    it "returns true" do
      record = TestReadOnlyRecord.new
      expect(record.readonly?).to be true
    end
  end

  describe "#before_destroy" do
    it "raises ActiveRecord::ReadOnlyRecord error" do
      record = TestReadOnlyRecord.new
      expect { record.before_destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end