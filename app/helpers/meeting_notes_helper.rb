module MeetingNotesHelper
  MEETING_NOTE_TITLES = { "midweek" => "Life and Ministry", "weekend" => "Weekend meeting" }.freeze
  # Primer functional colours, as drawn in docs/design/meeting-notes/notes-list.png.
  MEETING_NOTE_DOTS = { "midweek" => :danger, "weekend" => :muted }.freeze

  def meeting_note_title(note)
    MEETING_NOTE_TITLES.fetch(note.kind)
  end

  def meeting_note_dot(color)
    render Primer::Beta::Octicon.new(:"dot-fill", color: color, mr: 1)
  end

  # A gem's insight inline after its reference (frame shared-note-read-only.png), each typed line break
  # kept as a <br>, so a blank line between paragraphs still shows. Escaped: the insight is plain text.
  def meeting_note_insight(insight)
    safe_join(insight.strip.split(/\r?\n/), tag.br)
  end

  # "2 gems, 3 parts with notes", "Nothing written yet", or "Not started" for a note that doesn't exist yet.
  def meeting_note_summary(note)
    return "Not started" if note.new_record?

    counts = []
    counts << pluralize(note.gems.size, "gem") if note.gems.any?
    counts << "#{pluralize(note.filled_parts.size, "part")} with notes" if note.filled_parts.any?
    counts.join(", ").presence || "Nothing written yet"
  end
end
