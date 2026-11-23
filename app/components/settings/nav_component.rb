# frozen_string_literal: true

# The section nav (docs/design/settings.md, The section nav, On a phone): a NavList from md up, and below md a menu
# button named after the current section. The "You" group, then a group headed with the household's name holding the
# sections the person's role may change, as HouseholdPolicy decides. A child gets no household group, and a person who
# is a child in every household no Study guide.
class Settings::NavComponent < ApplicationComponent
  # Each section's id is its controller's, and its page is household_settings_<id>_path.
  SECTIONS = { profile: "Profile", appearance: "Appearance", sign_in: "Signing in", memberships: "My households", tags: "Tags and collections",
               calendar: "Calendar", notifications: "Notifications", study_guide: "Study guide" }.freeze
  HOUSEHOLD_SECTIONS = { household: "Household", meetings: "Meetings", children: "Children", go_bag_categories: "Go bags",
                         members: "Members and roles" }.freeze
  LABELS = SECTIONS.merge(HOUSEHOLD_SECTIONS).freeze

  attr_reader :membership, :selected

  delegate :household, to: :membership

  def initialize(membership:, selected:)
    @membership = membership
    @selected = selected
  end

  # [heading, sections] pairs; the household's group only when the role allows a section of it.
  def groups
    [ [ "You", your_sections ], [ household.name, household_sections ] ].reject { |_, sections| sections.empty? }
  end

  def selected_label
    LABELS.fetch(selected)
  end

  def section_path(section)
    public_send(:"household_settings_#{section}_path", household_id: household.id)
  end

  private
    # Study guide only for a head or adult in any household, whatever their role in this one
    # (docs/design/study-guide.md, Who can do what).
    def your_sections
      membership.user.may_have_study_guide? ? SECTIONS : SECTIONS.except(:study_guide)
    end

    # Household and Members and roles for heads; Meetings and Children for heads and adults; Go bags as
    # GoBag::CategoryPolicy allows, heads and adults.
    def household_sections
      policy = HouseholdPolicy.new(membership, household)
      HOUSEHOLD_SECTIONS.select do |id, _|
        case id
        when :meetings, :children then policy.manage_meetings?
        when :go_bag_categories then GoBag::CategoryPolicy.new(membership, GoBag::Category).index?
        else policy.update?
        end
      end
    end
end
