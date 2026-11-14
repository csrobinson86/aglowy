# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.

# A meeting note part's title and speaker are encrypted personal text; a bare :title would also hide every
# other title. Between the names: dots in nested params, brackets in a logged query string. The index segment
# is optional: parts sent as an array have no index. The \. keeps the regexp matched against the full key.
meeting_note_part_key = /\Ameeting_note[\.\[\]]+parts_attributes[\.\[\]]+(?:[^\.\[\]]+[\.\[\]]+)?(?:title|speaker)\]?\z/i

Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :notes, :insight,
  meeting_note_part_key,
  # Rails filters a logged query string's keys before decoding them, so decode each one (%73peaker is speaker,
  # %5B is [) and match it again. CGI.unescape leaves a malformed escape alone; Rack rejects that key anyway.
  ->(key, value) { value.replace("[FILTERED]") if value.is_a?(String) && meeting_note_part_key.match?(CGI.unescape(key.to_s).scrub) }
]
