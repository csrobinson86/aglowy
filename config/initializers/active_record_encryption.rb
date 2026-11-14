# Active Record encryption keys (encrypted session notes) come from credentials
# (active_record_encryption.*). On a machine without the credentials key, the
# ACTIVE_RECORD_ENCRYPTION_* environment variables stand in for missing ones. Credentials
# always win, so the two sources can't disagree. Test fixes its keys in config/environments/test.rb.
ActiveSupport.on_load(:active_record_encryption) do
  configured = Rails.application.credentials.active_record_encryption.to_h.merge(Rails.application.config.active_record.encryption)

  %i[ primary_key deterministic_key key_derivation_salt ].each do |key|
    fallback = ENV["ACTIVE_RECORD_ENCRYPTION_#{key.upcase}"]
    config.public_send(:"#{key}=", fallback) if configured[key].blank? && fallback.present?
  end
end
