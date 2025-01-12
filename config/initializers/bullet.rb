if defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = true             # Browser pop-ups
  Bullet.console = true           # Logs in the Rails console
  Bullet.rails_logger = true      # Logs in development.log
  Bullet.add_footer = true        # Notifications in the page footer
  Bullet.n_plus_one_query_enable = true
  Bullet.unused_eager_loading_enable = true
  Bullet.counter_cache_enable = true # Detects missing counter caches
end
