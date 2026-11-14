# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.

# Between the names in a meeting note part's key: dots in nested params, or brackets, plain or percent-encoded,
# in a logged query string (Rails filters its keys raw). The \. keeps the regexp matched against the full key.
part_key_separator = /(?:[\.\[\]]|%5[BD])+/i

Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :notes, :insight,
  # A meeting note part's title and speaker are encrypted personal text; a bare :title would also hide every
  # other title. The index segment is optional: parts sent as an array have no index in the filter path.
  /\Ameeting_note#{part_key_separator}parts_attributes#{part_key_separator}(?:[^\.\[\]%]+#{part_key_separator})?(?:title|speaker)(?:\]|%5D)?\z/i
]
