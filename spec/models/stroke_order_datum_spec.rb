require "rails_helper"

RSpec.describe StrokeOrderDatum, type: :model do
  describe "associations" do
    it { should belong_to(:dictionary_entry) }
  end

  describe "validations" do
    it { should validate_presence_of(:source) }
  end

  it "serializes strokes and medians as arrays" do
    datum = create(:stroke_order_datum, strokes: [ "M 0 0" ], medians: [ [ [ 0, 0 ], [ 1, 1 ] ] ])

    expect(datum.reload.strokes).to eq([ "M 0 0" ])
    expect(datum.medians).to eq([ [ [ 0, 0 ], [ 1, 1 ] ] ])
  end
end
