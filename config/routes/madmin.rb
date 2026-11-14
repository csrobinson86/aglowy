namespace :madmin do
  resources :identities
  resources :users
  resources :households, only: %i[ index show ]
  resources :memberships, only: %i[ index show ]
  root to: "dashboard#show"
end
