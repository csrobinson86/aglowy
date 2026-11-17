# A notification its person has opened, or marked read with the rest. State as a record (CLAUDE.md); it exists only to
# show what's unread, never to track anyone (docs/design/notifications.md, Guardrails).
class Notification::Reading < ApplicationRecord
  belongs_to :notification
end
