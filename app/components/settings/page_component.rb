# frozen_string_literal: true

# Every Settings page: the h1, the section nav, then the section's title, its one-line note and its boxes
# (docs/design/settings.md, The page). A household section's note starts with the household's name.
class Settings::PageComponent < ApplicationComponent
  NOTES = {
    profile: "Follows you to every household.",
    appearance: "Follows you to every household and device.",
    sign_in: "How you sign in to Aglowy.",
    memberships: "The households you belong to.",
    tags: "Rename or delete your tags and collections. Only you see them.",
    calendar: "Who sees your times, and your phone calendar link.",
    notifications: "What reaches you, and where. Follows you to every household.",
    household: "heads can change this.",
    meetings: "heads and adults can change this.",
    children: "heads and adults; AI for a child is heads only.",
    members: "heads only."
  }.freeze

  renders_one :body

  attr_reader :membership, :section

  def initialize(membership:, section:)
    @membership = membership
    @section = section
  end

  def title
    Settings::NavComponent::LABELS.fetch(section)
  end

  def note
    household_section? ? "#{membership.household.name} · #{NOTES.fetch(section)}" : NOTES.fetch(section)
  end

  private
    def household_section?
      Settings::NavComponent::HOUSEHOLD_SECTIONS.key?(section)
    end
end
