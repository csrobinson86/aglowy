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
  # A push subscription's address works as a secret (docs/design/notifications.md, PushSubscription).
  :endpoint,
  # AI prompts, chat messages and draft outlines (docs/design/ai.md, Traps).
  :prompt, :content, :outline,
  # A meeting part's preparation. Its other private fields are encrypted attributes, which Rails filters itself; this is
  # rich text, whose encrypted body is filtered only as encrypted_rich_text.body.
  :preparation,
  # A note's body: encrypted rich text again, filtered by Rails only as encrypted_rich_text.body.
  :body,
  # An email or a child's username, which says who is signing in.
  :login, :username,
  # A Get ready card change's encrypted fields. Rails filters them as card.<name>, which the form object's param key
  # doesn't match; quality isn't encrypted. Keep in step with PrepWeek::Card's encrypts and PrepWeek::Card::Change's
  # TEXTS and SENTENCES. The \. matches the full key.
  /\Aprep_week_card_change\.(?:about|quality_line|i_can|reading|story_\d+)\z/,
  meeting_note_part_key,
  # Rails filters a logged query string's keys before decoding them, so decode each one (%73peaker is speaker,
  # %5B is [) and match it again. CGI.unescape leaves a malformed escape alone; Rack rejects that key anyway.
  ->(key, value) { value.replace("[FILTERED]") if value.is_a?(String) && meeting_note_part_key.match?(CGI.unescape(key.to_s).scrub) }
]
