Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Returns 200 when the primary DB is reachable, 503 when the connection fails.
  get "up" => "health#show", as: :rails_health_check

  # OAuth 2.1 authorization server for MCP clients. No self-service application
  # management UI is exposed — CIMD clients are resolved automatically, so
  # :applications/:authorized_applications are skipped rather than left open.
  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
    # Resolves CIMD clients (client_id as an https:// metadata URL) before
    # Doorkeeper's own client lookup runs.
    controllers authorizations: "oauth/authorizations"
  end

  get "/.well-known/oauth-protected-resource",   to: "well_known#oauth_protected_resource"
  get "/.well-known/oauth-authorization-server", to: "well_known#oauth_authorization_server"

  # MCP server — Doorkeeper OAuth 2.1 bearer tokens, with a transitional CF
  # Access service-token fallback while existing clients migrate.
  post "mcp", to: "mcp#handle"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  get  "learn/progress",                    to: "progress#show",              as: :learn_progress
  get  "learn/progress/chart_data",         to: "progress#chart_data",        as: :learn_progress_chart_data
  get  "learn/progress/character_chart_data", to: "progress#character_chart_data", as: :learn_progress_character_chart_data

  get  "review",          to: "review#start",   as: :review
  get  "review/card",     to: "review#show",    as: :review_card
  post "review/card",     to: "review#submit"
  get  "review/summary",  to: "review#summary", as: :review_summary
  get  "review/history",  to: "review#history", as: :review_history

  resources :anki_imports, only: %i[new create show]
  resource  :data_export,  only: %i[show]
  resources :data_imports, only: %i[new create]

  get  "auth/oidc/callback", to: "omniauth_callbacks#create", as: :omniauth_callback
  get  "auth/failure",       to: "omniauth_callbacks#failure",                as: :auth_failure

  resource :settings, only: %i[show update]
  delete "settings/connected_apps/:id", to: "settings#revoke_connected_app", as: :revoke_connected_app
  get "sign_in", to: "sessions#new", as: :sign_in
  resource :session, only: %i[destroy]
  resources :tags, only: [ :index, :show ]
  resources :dictionary_entries, only: [ :show ]

  namespace :admin do
    root to: "dashboard#index"
    post "provision_all", to: "dashboard#provision_all", as: :provision_all
    resources :tasks, only: [ :create ] do
      member { post :retry }
    end
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end
end
