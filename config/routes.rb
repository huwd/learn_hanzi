Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  get  "learn",          to: "learn#start",        as: :learn
  get  "learn/card",     to: "learn#show",         as: :learn_card
  post "learn/card",     to: "learn#submit"
  get  "learn/review",   to: "learn#review_show",  as: :learn_review
  post "learn/review",   to: "learn#review_submit"
  get  "learn/summary",  to: "learn#summary",      as: :learn_summary

  get  "review",          to: "review#start",   as: :review
  get  "review/card",     to: "review#show",    as: :review_card
  post "review/card",     to: "review#submit"
  get  "review/summary",  to: "review#summary", as: :review_summary
  get  "review/history",  to: "review#history", as: :review_history

  resources :anki_imports, only: %i[new create show]

  get  "auth/oidc/callback", to: "omniauth_callbacks#create", as: :omniauth_callback
  get  "auth/failure",       to: "omniauth_callbacks#failure",                as: :auth_failure

  resource :settings, only: %i[show update]
  get "sign_in", to: "sessions#new", as: :sign_in
  resource :session, only: %i[destroy]
  resources :tags, only: [ :index, :show ]
  resources :dictionary_entries, only: [ :show ]
end
