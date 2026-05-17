# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "hanzi-writer", to: "hanzi-writer.js"
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.9/auto/+esm"
pin_all_from "app/javascript/controllers", under: "controllers"
