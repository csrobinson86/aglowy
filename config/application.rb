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

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Active Record encryption keys (encrypted session notes). Rails reads them from
    # credentials (active_record_encryption.*); these environment variables win when set,
    # for machines without the credentials key. Test fixes its own in config/environments/test.rb.
    config.active_record.encryption.merge!({
      primary_key: ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"],
      deterministic_key: ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"],
      key_derivation_salt: ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
    }.compact_blank)

    # Action Text needs Active Storage, but nothing uploads yet: notes have attachments off.
    # Its public upload and blob routes stay undrawn until the file story adds guarded ones
    # (docs/design/family-studies.md, Files).
    config.active_storage.draw_routes = false
    config.active_storage.variant_processor = :disabled

    # Limits for family studies, one place each (docs/design/family-studies.md, "Limits").
    config.x.family_studies.max_file_size   = 25.megabytes
    config.x.family_studies.file_types      = %w[ application/pdf image/png image/jpeg image/gif image/webp image/heic ]
    config.x.family_studies.minimum_horizon = 3.months
  end
end

require "view_component"
require "primer/view_components"
