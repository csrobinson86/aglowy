require "application_system_test_case"

class FamilyStudiesTest < ApplicationSystemTestCase
  test "Family studies is selected in the sidebar, and the list passes assert_accessible" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    within("nav[aria-label='Main']") { click_on "Family studies" }

    assert_selector "h1", text: "Family studies"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Family studies"
    assert_selector ".Box-row", count: 4
    assert_accessible
    capture_screens("family-studies")
  end

  test "the empty state passes assert_accessible" do
    sign_in identities(:outsider)

    visit household_family_studies_url(household_id: households(:other))

    assert_selector "h2", text: "No family studies yet"
    assert_accessible
    capture_screens("family-studies-empty")
  end
end
