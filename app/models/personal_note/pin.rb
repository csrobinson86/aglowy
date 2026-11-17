# A note pinned to the top of Notes and onto Home, as a record: it exists while the note is pinned
# (docs/design/notes.md, PersonalNote::Pin). Only made through PersonalNote#pin_to_top; #unpin deletes it.
class PersonalNote::Pin < ApplicationRecord
  belongs_to :personal_note
end
