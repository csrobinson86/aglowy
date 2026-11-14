# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :notes, :insight,
  # A meeting note part's title is encrypted personal text; a bare :title would also hide every other title.
  # The index segment is optional: parts sent as an array have no index in the filter path.
  /\Ameeting_note\.parts_attributes\.(?:[^.]+\.)?title\z/
]
