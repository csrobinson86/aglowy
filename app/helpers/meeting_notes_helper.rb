module MeetingNotesHelper
  MEETING_NOTE_TITLES = MeetingNote::TITLES
  # Primer functional colours, as drawn in docs/design/meeting-notes/notes-list.png.
  MEETING_NOTE_DOTS = { "midweek" => :danger, "weekend" => :muted }.freeze
  # One row of the Meetings list on the Meeting notes tab; a nil kind is All meetings.
  MeetingNoteKindFilter = Data.define(:kind, :label, :dot, :count)
  # The meeting helper's own decorative icons, inline so they take the text colour. Each file carries aria-hidden.
  MEETING_HELPER_ICONS = Rails.root.glob("app/assets/images/meeting_helper/*.svg").to_h { [ it.basename(".svg").to_s, it.read.html_safe ] }.freeze
  # The drawing page's seven colours (frame tablet-draw.png), first picked first. Each swatch's BEM modifier
  # takes its colour from a Primer primitive, and the canvas draws in the picked swatch's colour.
  MEETING_HELPER_COLOURS = %w[ yellow orange red green blue purple white ].freeze
  # The helper's "Which meeting is it?" cards (frame tablet-pick.png).
  MEETING_HELPER_PICKER_ICONS = { "midweek" => { icon: "book", color: :accent }, "weekend" => { icon: "ear", color: :attention } }.freeze

  def meeting_note_title(note)
    MEETING_NOTE_TITLES.fetch(note.kind)
  end

  # "All meetings", then each meeting, with its dot and how many of the list's notes are for it.
  def meeting_note_kind_filters(kind_counts)
    [ MeetingNoteKindFilter.new(kind: nil, label: "All meetings", dot: :muted, count: kind_counts.values.sum) ] +
      MEETING_NOTE_TITLES.map { |kind, title| MeetingNoteKindFilter.new(kind:, label: title, dot: MEETING_NOTE_DOTS.fetch(kind), count: kind_counts.fetch(kind, 0)) }
  end

  def meeting_note_dot(color)
    render Primer::Beta::Octicon.new(:"dot-fill", color: color, mr: 1)
  end

  # One of the meeting helper's icons in its tone's circle (docs/design/meeting-helper.md, The helper's steps).
  def meeting_helper_icon(icon:, color:, size: nil)
    tag.span(MEETING_HELPER_ICONS.fetch(icon), class: [ "meeting-helper__icon", "meeting-helper__icon--#{color}", ("meeting-helper__icon--#{size}" if size) ])
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

  # "Private", or who can read it: "Shared with The Rivera household" (frames life-and-ministry-note.png, share-dialog.png).
  # Every household it's shared with, not just this one, so a note never reads "Private" while others can read it.
  def meeting_note_sharing_label(note)
    note.shared_households.any? ? "Shared with #{note.shared_households.map(&:name).to_sentence}" : "Private"
  end

  # The hint beside "Save notes".
  def meeting_note_save_hint(note)
    if note.shared_households.any?
      "Members of #{note.shared_households.map(&:name).to_sentence} can read this note."
    else
      "Only you can see this note."
    end
  end
end
