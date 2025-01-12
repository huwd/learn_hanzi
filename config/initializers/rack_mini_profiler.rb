if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.position = "top-right" # or 'bottom-right'
  Rack::MiniProfiler.config.start_hidden = false   # Set to true if you want to hide it by default
end
