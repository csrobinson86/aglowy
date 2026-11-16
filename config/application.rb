require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Aglowy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Lets a locale drop the attribute name from a full message, as Primer forms show full messages beside the input.
    config.active_model.i18n_customize_full_message = true

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Active Storage's own blob routes are signed, not authorized (gotcha 22), so they stay undrawn.
    # config/routes.rb draws only the guarded direct upload and the Disk service's short-lived URLs;
    # files are served through Resources::FilesController (docs/design/family-studies.md, Files).
    config.active_storage.draw_routes = false
    config.active_storage.variant_processor = :disabled
    # No previews or thumbnails. Without previewers Lexxy adds no preview URL to a direct upload's
    # response either, which would need the undrawn representation routes.
    config.active_storage.previewers = []
    config.active_storage.service_urls_expire_in = 5.minutes

    # Lexxy widens Action Text's allowed tags for its media attachments. Notes take only scripture
    # links, so take the media tags back: nobody can post an <embed> or <video> that everyone in
    # the household then loads. Ordered after Lexxy's, which sets the list after boot too.
    # A scripture link (bible/references/_reference) is rendered before the note is sanitized, so
    # RichTextScrubber sanitizes with these lists plus the link's target="_blank" and rel="noopener".
    # It's app code, so it's found at the first render rather than at boot; it scrubs bottom up, as
    # Rails' own PermitScrubber does. The link's icon is an <svg>, which stays out of user content:
    # CSS draws it instead.
    initializer "aglowy.action_text_sanitizer", after: "lexxy.sanitization" do |app|
      app.config.after_initialize do
        ActionText::ContentHelper.allowed_tags -= %w[ embed video audio source ]
        ActionText::ContentHelper.scrubber = Loofah::Scrubber.new(direction: :bottom_up) { RichTextScrubber.instance.scrub(it) }
      end
    end

    # Limits for family studies, one place each (docs/design/family-studies.md, "Limits").
    config.x.family_studies.max_file_size   = 25.megabytes
    config.x.family_studies.file_types      = %w[ application/pdf image/png image/jpeg image/gif image/webp image/heic ]
    config.x.family_studies.minimum_horizon = 3.months
    config.x.storage.household_quota        = 2.gigabytes
    config.x.storage.warning_ratio          = 0.8

    # Every email's sender, Devise's included (config/initializers/devise.rb).
    config.x.mail_from = ENV.fetch("MAIL_FROM", "Aglowy <hello@localhost>")
  end
end

require "view_component"
require "primer/view_components"
