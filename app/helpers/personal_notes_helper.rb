module PersonalNotesHelper
  # An item in Notes' "All notes ▾" menu on a phone (personal_notes/_phone_menu). The ones the list is showing are
  # marked current, and drawn the way Primer's NavList draws its selected item, with NavList's own class. It isn't an
  # ActionMenu argument, so after a Primer upgrade look at the phone-notes-menu screenshot.
  def notes_menu_item(list, current:, **)
    list.with_item(classes: ("ActionListItem--navActive" if current), content_arguments: { "aria-current": ("true" if current) }, truncate_label: true, **)
  end

  # A note row's muted line on a phone (docs/design/phone.md, Notes): "Ministry · Nov 10 · Listen first…", leaving out
  # a collection or preview it doesn't have. The date is when the note was last edited, in the household's time zone:
  # "today", "Nov 10", or "Nov 10, 2025" in another year. The body is decrypted in Ruby and escaped like any text.
  def note_row_line(personal_note)
    today = Current.household.today
    edited_on = personal_note.updated_at.in_time_zone(Current.household.time_zone).to_date
    date = edited_on == today ? "today" : edited_on.strftime(edited_on.year == today.year ? "%b %-d" : "%b %-d, %Y")
    [ personal_note.collection&.name, date, personal_note.body.to_plain_text.squish.truncate(160) ].compact_blank.join(" · ")
  end
end
