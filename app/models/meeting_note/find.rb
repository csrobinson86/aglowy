# The child found the right card in a round of the listening game (docs/design/listening-game.md, MeetingNote::Find).
# It keeps its own label and kind, copied from the card, so the note reads the same after the game is purged or a
# parent changes the round (Trap 5). The unique index on the note, step and round keeps it to one find per round.
class MeetingNote::Find < ApplicationRecord
  belongs_to :meeting_note
end
