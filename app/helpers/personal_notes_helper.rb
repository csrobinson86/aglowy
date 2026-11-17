module PersonalNotesHelper
  # An item in Notes' "All notes ▾" menu on a phone (personal_notes/_phone_menu). The ones the list is showing are
  # marked current, and drawn the way Primer's NavList draws its selected item, with NavList's own class. It isn't an
  # ActionMenu argument, so after a Primer upgrade look at the phone-notes-menu screenshot.
  def notes_menu_item(list, current:, **)
    list.with_item(classes: ("ActionListItem--navActive" if current), content_arguments: { "aria-current": ("true" if current) }, truncate_label: true, **)
  end
end
