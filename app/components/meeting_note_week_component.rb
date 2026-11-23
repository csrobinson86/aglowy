# frozen_string_literal: true

# A week in the Meeting notes tab's Earlier list: a Primer Details whose summary shows the week, a dot per note and
# whether any is shared, and which opens to the week's notes (docs/design/notes.md, Earlier, a week at a time; frames
# notes-meeting-notes-weeks.png and phone-notes-meeting-notes-weeks.png). Pass the notes in_week_order, with their gems
# and parts' notes for the summary, and their sharings and tags on my list or their users on the shared list, preloaded,
# so a page asks no query per note.
class MeetingNoteWeekComponent < ApplicationComponent
  attr_reader :week_of, :notes

  # shared_list: the household's shared list, where each row names its author and the week has no Shared label.
  def initialize(week_of:, notes:, open: false, shared_list: false)
    @week_of = week_of
    @notes = notes
    @open = open
    @shared_list = shared_list
  end

  def open? = @open
  def shared_list? = @shared_list

  def shared?
    !shared_list? && notes.any? { it.sharings.any? }
  end

  def dot_color(note)
    MeetingNotesHelper::MEETING_NOTE_DOTS.fetch(note.kind)
  end

  # The author on the shared list, then the weekend's days (a Life and Ministry row drops the week, since the week's
  # summary has it), then what's written: "2 gems, 1 part with notes".
  def details(note)
    [ (note.user.name if shared_list?), (note.display_week if note.weekend?), helpers.meeting_note_summary(note) ].compact.join(" · ")
  end

  def note_path(note)
    household_meeting_note_path(household_id: Current.household, id: note)
  end
end
