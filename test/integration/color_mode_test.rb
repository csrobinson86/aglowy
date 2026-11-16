require "test_helper"

# Every layout but the meeting helper's and the design system's follows the person's Appearance choice
# (docs/design/app-shell.md, Theming and appearance).
class ColorModeTest < ActionDispatch::IntegrationTest
  test "a person who chose dark gets it on the household home and on account settings" do
    users(:head).update!(appearance: "dark")
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))
    assert_select "body[data-color-mode=dark][data-light-theme=light][data-dark-theme=dark]"

    get edit_account_path
    assert_select "main h1", "Account settings"
    assert_select "body[data-color-mode=dark][data-light-theme=light][data-dark-theme=dark]"
  end

  test "a person who chose light gets it on the household home" do
    users(:spouse).update!(appearance: "light")
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select "body[data-color-mode=light]"
  end

  test "the sign-in page, signed out, is auto" do
    get new_identity_session_path

    assert_select "body[data-color-mode=auto][data-light-theme=light][data-dark-theme=dark]"
  end

  test "a child who chose light still gets dark in the meeting helper on today's meeting" do
    households(:home).enable_meeting_helper(by: users(:head))
    users(:eli).update!(appearance: "light")
    sign_in identities(:eli)

    get household_todays_meeting_path(household_id: households(:home))

    assert_select "nav[aria-label='Main']", count: 0
    assert_select "body[data-color-mode=dark]"
  end
end
