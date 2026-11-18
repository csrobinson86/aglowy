Rails.application.routes.draw do
  draw :madmin
  devise_for :identities, skip: :registrations
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # The PWA manifest (linked in layouts/_head) and the service worker that shows pushes, from app/views/pwa/*
  # (docs/design/notifications.md, Push).
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

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
  # A person's photo, one URL on every page, outside the household scope: it's the same in each (docs/design/avatars.md).
  get "people/:user_id/avatar", to: "avatars#show", as: :avatar
  # /invitation?token=…: the token is a query parameter, never a path segment, so filtered_path keeps it out of
  # the Rails log and Lograge (docs/design/invitations.md, Traps). Destroy is declining.
  resource :invitation_acceptance, path: "invitation", only: %i[ show create destroy ]
  # /password_setup?token=…, where a child chooses a password from the link a head or adult made
  # (docs/design/invitations.md, Child logins). A query parameter for the same reason as the invitation's token.
  resource :password_setup, only: %i[ edit update ], path_names: { edit: "" }
  resources :households, only: %i[ index new create ]
  # Turning on AI drafts, for the person wherever they are: acceptance is theirs, not a household's (docs/design/ai.md).
  resource :ai_acceptance, only: :create
  # A scripture link for the notes editor, /scriptures/19:37:8-9, signed on the server (docs/design/scripture-links.md, Pieces).
  # No household: a Bible reference isn't anyone's record.
  resources :scriptures, only: :show
  # A person's phone calendar, /calendar/<token>.ics, with no session: the token is the authorization
  # (docs/design/calendar.md, The phone feed). Outside the household scope, since it covers all their households.
  get "calendar/:token", to: "calendar_feeds#show", as: :calendar_feed, format: true, constraints: { format: "ics" }
  # "Turn off this email", from an email's footer and its one-click header, with no session: the signed token is the
  # authorization, good only for its scope, a right-away kind or "summary" (docs/design/notifications.md, Emails).
  resource :email_unsubscribe, only: %i[ show create ], path: "unsubscribe/:scope/:token"
  # Account settings at /account, always the signed-in person's own: no id in the URL (docs/design/invitations.md).
  # Only for a person with no household: with one, GET /account opens Settings (docs/design/settings.md, /account stays).
  # The appearance and sign-in details forms on the same page post to /account/appearance and /account/sign_in;
  # leaving a household deletes /account/memberships/:id, one of the person's own active seats.
  resource :account, only: %i[ edit update ], path_names: { edit: "" } do
    resource :appearance, only: :update, module: :accounts
    resource :sign_in, only: %i[ edit update ], module: :accounts, path_names: { edit: "" }
    resources :memberships, only: :destroy, module: :accounts
  end

  namespace :admin do
    resource :impersonation, only: [ :create, :destroy ]
  end

  scope "/:household_id", as: :household,
        constraints: { household_id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ } do
    get "/", to: "dashboards#show", as: :root
    # Meetings, family studies and events by week or month: ?view=week|month&date=2026-11-17&hide[]=meetings (docs/design/calendar.md).
    resource :calendar, only: :show
    # Household events, added and edited in a dialog on the calendar.
    namespace :calendar do
      resources :events, only: %i[ new create edit update destroy ]
    end
    # The signed-in person's own times, found through Current.user, added and edited in a dialog on the calendar. A done
    # mark is created with the day as on, and deleted with the day as its id (completions/2026-11-17).
    resources :personal_times, only: %i[ new create edit update destroy ] do
      resources :completions, only: %i[ create destroy ], module: :personal_times
    end
    # Settings, a page per section, opening on Profile for everyone (docs/design/settings.md, Pages and routes).
    get "settings", to: redirect("/%{household_id}/settings/profile"), as: :settings
    # The person's own sections, the same person from any household; then the household's, each for the roles that
    # may change it (docs/design/settings.md, Sections and who sees them).
    namespace :settings do
      resource :profile, only: %i[ show update ]
      resource :avatar, only: %i[ update destroy ]         # Your photo and initial's color, in Profile (docs/design/avatars.md)
      resource :appearance, only: %i[ show update ]
      resource :sign_in, only: %i[ show update ]
      resources :memberships, only: %i[ index destroy ]   # My households
      resources :tags, only: :index                        # Tags and collections
      resource :calendar, only: :show                      # Calendar: who sees your times (docs/design/calendar.md)
      resource :time_sharing, only: :update                # Share my times
      resource :calendar_feed, only: :update               # Reset link
      resource :notifications, only: %i[ show update ]     # Notifications: what also comes by email (docs/design/notifications.md)
      resource :quiet_hours, only: :update                 # Quiet hours
      resource :household, only: %i[ show update ]         # Heads
      resource :meetings, only: %i[ show update ]          # Heads and adults
      resource :children, only: :show                      # Heads and adults
      resources :children, only: [] do                     # A child's photo and initial's color, heads and adults
        resource :avatar, only: %i[ update destroy ], module: :children
      end
      resource :meeting_helper, only: :update              # Children's meeting helper switch
      resources :members, only: :index                     # Members and roles, heads
    end
    # Changing a role and removing a member are on Settings → Members and roles, heads only (docs/design/invitations.md).
    resources :members, only: %i[ index new create destroy ] do
      resource :login, only: %i[ new create ], module: :members, path_names: { new: "" }
      resource :password_link, only: :create, module: :members
      resource :role, only: :update, module: :members
      # A head's read-only view of a child's personal studies, under a study AI grant (docs/design/personal-study.md, Children).
      resources :personal_studies, only: %i[ index show ], module: :members
    end
    # Turning personal study with AI on or off for a child, from Settings → Children; heads only.
    resources :memberships, only: [] do
      resource :study_ai_grant, only: %i[ create destroy ], module: :memberships
    end
    resources :invitations, only: %i[ new create update destroy ]
    # Drafting a study with AI, from the panel beside the Schedule form (docs/design/family-studies.md, AI helper).
    # destroy is Stop while drafting, and Discard after.
    scope "family_studies", module: :family_studies, as: :family_study do
      resources :drafts, only: %i[ create show destroy ]
    end
    resources :family_studies, only: %i[ index new create ] do
      resources :sessions, only: %i[ show edit update ], module: :family_studies do
        resource :notes, only: %i[ edit update ], module: :sessions
        resource :cancellation, only: %i[ create destroy ], module: :sessions
        resources :resources, only: %i[ create destroy ], module: :sessions
        resources :files, only: :create, module: :sessions
      end
    end
    # The inbox, from all the person's households; show reads one and opens it, and readings is Mark all as read
    # (docs/design/notifications.md, Pages and routes).
    resources :notifications, only: %i[ index show ] do
      collection { resource :readings, only: :create, module: :notifications, as: :notifications_readings }
    end
    # Turn on for this browser and Remove, in Settings → Notifications; always the person's own devices.
    resources :push_subscriptions, only: %i[ create destroy ]
    # The signed-in person's daily brief and its plan, for heads and adults (docs/design/daily-brief.md, Pages and routes).
    # Focus areas are added and edited in a dialog on Your plan, and found through the person's own plan. A day's wday is
    # one digit, 0 to 6: the column is an integer, so "2-x" would otherwise be cast to 2.
    resource :daily_brief, only: [] do
      resource :plan, only: %i[ new create show update ], module: :daily_briefs do
        resource :pause, only: %i[ create destroy ], module: :plans
        resources :focus_areas, only: %i[ new create edit update destroy ], module: :plans
        resources :days, only: %i[ edit update ], module: :plans, param: :wday, constraints: { wday: /[0-6]/ }
      end
    end
    # Each person's own note for the current or next meeting; show never creates anything (docs/design/meeting-helper.md).
    resource :todays_meeting, only: %i[ show create ]
    resources :meeting_notes, only: %i[ index create show edit update ] do
      resource :sharing, only: %i[ create destroy ], module: :meeting_notes
      # The owner's own tags on it; :id is the tag's (docs/design/tags.md, Pages and routes).
      resources :taggings, only: %i[ create destroy ], module: :meeting_notes
      # The meeting helper's steps, one at a time; :id is the step's key (MeetingNote::HelperSteps).
      resources :steps, only: :show, module: :meeting_notes do
        resource :mark, only: %i[ create destroy ], module: :steps
        # edit and update are helper pages; show serves the image to anyone who can read the note.
        resource :drawing, only: %i[ show edit update ], module: :steps
      end
      # The helper's end screen, after the last step.
      resource :summary, only: :show, module: :meeting_notes
    end
    resources :shared_meeting_notes, only: :index
    # The signed-in person's own student parts, found through Current.user; new and edit open in a dialog
    # (docs/design/meeting-parts.md, Pages and routes). A part shared into this household is read through show.
    resources :meeting_parts do
      resource :sharing, only: %i[ create destroy ], module: :meeting_parts
      # Prepare with AI, for heads and adults on their own part (docs/design/meeting-parts.md, Prepare with AI).
      resources :drafts, only: %i[ create show destroy ], module: :meeting_parts
    end
    resources :shared_meeting_parts, only: :index
    # The signed-in person's own goals; each opens at /goals/:id like a family goal (docs/design/goals.md, Pages).
    resources :my_goals, only: %i[ index new create ], controller: "personal_goals"
    resources :goals, only: %i[ index new create show edit update destroy ] do
      resource :completion, only: %i[ create destroy ], module: :goals
      resource :archival, only: %i[ create destroy ], module: :goals
      resource :sharing, only: %i[ create destroy ], module: :goals
      # A personal goal's owner's tags; a family goal is a 404 (docs/design/tags.md, Traps).
      resources :taggings, only: %i[ create destroy ], module: :goals
      resources :steps, only: %i[ create update destroy ], module: :goals do
        resources :completions, only: %i[ create destroy ], module: :steps
      end
    end
    # The signed-in person's own studies, found through Current.user (docs/design/personal-study.md, Pages and routes).
    resources :personal_studies, only: %i[ index new create show update destroy ] do
      resources :taggings, only: %i[ create destroy ], module: :personal_studies
      resources :questions, only: %i[ create destroy ], module: :personal_studies do
        # Save to notes on an answer card: appends the answer to the study's notes.
        resource :note_saving, only: :create
        # Save as a note: a new note holding the answer (docs/design/notes.md, Save an AI answer as a note).
        resource :personal_note, only: :create
      end
    end
    # The signed-in person's own notes at /notes, found through Current.user (docs/design/notes.md, Pages and routes).
    resources :personal_notes, path: "notes", only: %i[ index new create show update destroy ] do
      resources :taggings, only: %i[ create destroy ], module: :personal_notes
      resource :pin, only: %i[ create destroy ], module: :personal_notes
    end
    # The signed-in person's own bookmarks, the third tab of Notes, found through Current.user (docs/design/bookmarks.md).
    # Saving from a study posts the page and the study; the title comes from the study, never the form. Editing changes
    # a page's title, the comment and the collection, never the page or scripture.
    resources :bookmarks, only: %i[ index create update destroy ] do
      resources :taggings, only: %i[ create destroy ], module: :bookmarks
    end
    # The person's folders, shared between Personal study and Notes.
    resources :collections, only: %i[ create update destroy ]
    # The signed-in person's own tags, found by name through Current.user, so another person's is a 404 (docs/design/tags.md).
    # Listed in Settings → Tags and collections.
    resources :tags, only: %i[ show update destroy ], param: :name
    resources :direct_uploads, only: :create
    resources :resources, only: [] do
      resource :file, only: :show, module: :resources
    end
  end

  if Rails.env.development?
    get "design-system" => "design_system#show"
  end
end
