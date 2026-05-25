if defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = true             # Browser pop-ups
  Bullet.console = true           # Logs in the Rails console
  Bullet.rails_logger = true      # Logs in development.log
  Bullet.add_footer = true        # Notifications in the page footer
  Bullet.n_plus_one_query_enable = true
  Bullet.unused_eager_loading_enable = true
  Bullet.counter_cache_enable = true # Detects missing counter caches

  # Cards without audio never touch this chain, and Bullet can't see
  # through the has_one_attached proxy even when audio is present.
  # The eager load is necessary for cards that do have audio.
  Bullet.add_safelist type: :unused_eager_loading, class_name: "DictionaryEntry", association: :audio_pronunciations
  Bullet.add_safelist type: :unused_eager_loading, class_name: "AudioPronunciation", association: :audio_attachment
  Bullet.add_safelist type: :unused_eager_loading, class_name: "ActiveStorage::Attachment", association: :blob

  # Cards without radicals never access this, but RadicalBreakdownBuilder
  # uses .loaded? to benefit from it for cards that do have radicals.
  Bullet.add_safelist type: :unused_eager_loading, class_name: "DictionaryEntry", association: :dictionary_entry_radicals
end
