FactoryBot.define do
  factory :audio_pronunciation do
    association :dictionary_entry
    source { AudioPronunciation::SOURCE_KRMANIK }
    locale { AudioPronunciation::LOCALE_ZH_CN }

    after(:build) do |audio_pronunciation|
      next if audio_pronunciation.audio.attached?

      audio_pronunciation.audio.attach(
        io: StringIO.new("fake mp3 data"),
        filename: "cmn-#{audio_pronunciation.dictionary_entry.text}.mp3",
        content_type: "audio/mpeg"
      )
    end
  end
end
