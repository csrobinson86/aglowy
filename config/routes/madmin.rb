namespace :madmin do
  resources :identities
  resources :users
  root to: "dashboard#show"
end
