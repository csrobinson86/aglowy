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
  # /invitation?token=…: the token is a query parameter, never a path segment, so filtered_path keeps it out of
  # the Rails log and Lograge (docs/design/invitations.md, Traps). Destroy is declining.
  resource :invitation_acceptance, path: "invitation", only: %i[ show create destroy ]
  # /password_setup?token=…, where a child chooses a password from the link a head or adult made
  # (docs/design/invitations.md, Child logins). A query parameter for the same reason as the invitation's token.
  resource :password_setup, only: %i[ edit update ], path_names: { edit: "" }
  resources :households, only: %i[ index new create ]
  # Account settings at /account, always the signed-in person's own: no id in the URL (docs/design/invitations.md).
  # The sign-in details form on the same page posts to /account/sign_in; leaving a household deletes
  # /account/memberships/:id, one of the person's own active seats.
  resource :account, only: %i[ edit update ], path_names: { edit: "" } do
    resource :sign_in, only: %i[ edit update ], module: :accounts, path_names: { edit: "" }
    resources :memberships, only: :destroy, module: :accounts
  end

  namespace :admin do
    resource :impersonation, only: [ :create, :destroy ]
  end

  scope "/:household_id", as: :household,
        constraints: { household_id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ } do
    get "/", to: "dashboards#show", as: :root
    # Household settings at /:household_id/settings, heads only (docs/design/invitations.md, Household settings).
    resource :settings, only: %i[ edit update ], controller: "households/settings", path_names: { edit: "" }
    resources :members, only: %i[ index new create ] do
      resource :login, only: %i[ new create ], module: :members, path_names: { new: "" }
      resource :password_link, only: :create, module: :members
    end
    resources :invitations, only: %i[ new create update destroy ]
    resources :family_studies, only: %i[ index new create ] do
      resources :sessions, only: %i[ show edit update ], module: :family_studies do
        resource :notes, only: %i[ edit update ], module: :sessions
        resource :cancellation, only: %i[ create destroy ], module: :sessions
        resources :resources, only: %i[ create destroy ], module: :sessions
        resources :files, only: :create, module: :sessions
      end
    end
    resources :meeting_notes, only: %i[ index create show edit update ] do
      resource :sharing, only: %i[ create destroy ], module: :meeting_notes
    end
    resources :shared_meeting_notes, only: :index
    resources :goals, only: %i[ index new create show edit update destroy ] do
      resource :completion, only: %i[ create destroy ], module: :goals
      resource :archival, only: %i[ create destroy ], module: :goals
      resources :steps, only: %i[ create update destroy ], module: :goals do
        resources :completions, only: %i[ create destroy ], module: :steps
      end
    end
    resources :direct_uploads, only: :create
    resources :resources, only: [] do
      resource :file, only: :show, module: :resources
    end
  end

  if Rails.env.development?
    get "design-system" => "design_system#show"
  end
end
