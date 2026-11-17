# frozen_string_literal: true

# The section nav (docs/design/settings.md, The section nav, On a phone): a NavList from md up, and below md a menu
# button named after the current section. Only the "You" group for now; the household's group comes in #218.
class Settings::NavComponent < ApplicationComponent
  # Each section's id is its controller's, and its page is household_settings_<id>_path.
  SECTIONS = { profile: "Profile", appearance: "Appearance", sign_in: "Signing in", memberships: "My households" }.freeze

  attr_reader :household, :selected

  def initialize(household:, selected:)
    @household = household
    @selected = selected
  end

  def sections
    SECTIONS
  end

  def section_path(section)
    public_send(:"household_settings_#{section}_path", household_id: household.id)
  end
end
