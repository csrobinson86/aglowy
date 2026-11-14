Rails.application.routes.draw do
  draw :madmin
  devise_for :identities, skip: :registrations
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # "/" sends a signed-in person where signing in would, and shows everyone
  # else the sign-in page. The visitor's root keeps the name root_path.
  authenticated :identity do
    root to: "landings#show", as: :authenticated_root
  end
  devise_scope :identity do
    root to: "devise/sessions#new"
  end

  # The Disk service's signed URLs, which expire after five minutes: direct uploads PUT to one, and
  # Resources::FilesController redirects to one after its policy check. Production storage comes with
  # the deploy epic. Active Storage's other routes stay undrawn (config/application.rb).
  scope ActiveStorage.routes_prefix do
    get "/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service
    put "/disk/:encoded_token" => "active_storage/disk#update", as: :update_rails_disk_service
  end

  resource :signup, only: %i[ new create ]
  resources :households, only: %i[ index new create ]

  namespace :admin do
    resource :impersonation, only: [ :create, :destroy ]
  end

  scope "/:household_id", as: :household,
        constraints: { household_id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ } do
    get "/", to: "dashboards#show", as: :root
    resources :members, only: %i[ index new create ]
    resources :family_studies, only: %i[ index new create ] do
      resources :sessions, only: %i[ show edit update ], module: :family_studies do
        resource :notes, only: %i[ edit update ], module: :sessions
        resource :cancellation, only: %i[ create destroy ], module: :sessions
        resources :resources, only: %i[ create destroy ], module: :sessions
        resources :files, only: :create, module: :sessions
      end
    end
    resources :meeting_notes, only: %i[ index create show edit update ]
    resources :direct_uploads, only: :create
    resources :resources, only: [] do
      resource :file, only: :show, module: :resources
    end
  end

  if Rails.env.development?
    get "design-system" => "design_system#show"
  end
end
