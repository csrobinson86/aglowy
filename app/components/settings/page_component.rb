# frozen_string_literal: true

# Every Settings page: the h1, the section nav, then the section's title, its one-line note and its boxes
# (docs/design/settings.md, The page).
class Settings::PageComponent < ApplicationComponent
  NOTES = {
    profile: "Follows you to every household.",
    appearance: "Follows you to every household and device.",
    sign_in: "How you sign in to Aglowy.",
    memberships: "The households you belong to."
  }.freeze

  renders_one :body

  attr_reader :household, :section

  def initialize(household:, section:)
    @household = household
    @section = section
  end

  def title
    Settings::NavComponent::SECTIONS.fetch(section)
  end

  def note
    NOTES.fetch(section)
  end
end
