# frozen_string_literal: true

# Notes' tabs: Notes, Meeting notes and Bookmarks, each with how many the person has (docs/design/notes.md, Notes,
# Meeting notes and Bookmarks). The shared list selects Meeting notes.
class NotesTabsComponent < ApplicationComponent
  Tab = Data.define(:id, :label, :icon, :href, :count)

  attr_reader :selected, :membership

  delegate :household, :user, to: :membership

  def initialize(selected:, membership: Current.membership)
    @selected = selected
    @membership = membership
  end

  def tabs
    [
      Tab.new(id: :personal_notes, label: "Notes", icon: :pencil, href: household_personal_notes_path(household_id: household.id), count: user.personal_notes.count),
      Tab.new(id: :meeting_notes, label: "Meeting notes", icon: :note, href: household_meeting_notes_path(household_id: household.id), count: user.meeting_notes.count),
      Tab.new(id: :bookmarks, label: "Bookmarks", icon: :bookmark, href: household_bookmarks_path(household_id: household.id), count: user.bookmarks.count)
    ]
  end
end
