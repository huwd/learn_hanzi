require "rails_helper"

RSpec.describe AudioPronunciation do
  # -------------------------------------------------------------------
  # Query count: proves eager-loading the full ActiveStorage chain
  # eliminates the 2 extra queries per card (attachment + blob).
  #
  # The card controllers include:
  #   audio_pronunciations: { audio_attachment: :blob }
  #
  # Without the attachment/blob part Rails fires 2 extra queries every
  # time content_type or blob attributes are accessed:
  #   1. SELECT active_storage_attachments WHERE record_id = ...
  #   2. SELECT active_storage_blobs WHERE id = ...
  # -------------------------------------------------------------------
  describe "eager loading" do
    let!(:entry) { create(:dictionary_entry, text: "学") }
    let!(:audio_pronunciation) { create(:audio_pronunciation, dictionary_entry: entry) }

    it "eliminates attachment and blob queries when the full chain is pre-loaded" do
      partial_entry = DictionaryEntry.includes(:audio_pronunciations).find(entry.id)
      full_entry    = DictionaryEntry.includes(audio_pronunciations: { audio_attachment: :blob }).find(entry.id)

      baseline  = count_queries { partial_entry.audio_pronunciations.first.audio.content_type }
      optimised = count_queries { full_entry.audio_pronunciations.first.audio.content_type }

      expect(baseline - optimised).to eq(2),
        "expected pre-loading to save 2 queries (attachment + blob), " \
        "but saved #{baseline - optimised} (#{baseline} → #{optimised})"
    end
  end
end
