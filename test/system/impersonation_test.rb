require "application_system_test_case"

class ImpersonationTest < ApplicationSystemTestCase
  test "staff impersonating someone see the warning banner and stop impersonating from it" do
    sign_in identities(:staff)
    visit madmin_identity_url(identities(:head))
    click_on "Impersonate"

    assert_selector "main > .flash:not(.Banner):first-child", text: "Now impersonating head@example.com"
    assert_selector "main x-banner .Banner--warning", text: "You're using Hannah Head's account (head@example.com)."
    assert_button "Stop impersonating", count: 1
    assert_accessible
    capture_screens("impersonating-flash")

    find(".flash:not(.Banner) .js-flash-close").click
    assert_no_selector ".flash:not(.Banner)"

    visit household_root_url(household_id: households(:home))
    assert_selector "main .container-xl > x-banner:first-child .Banner--warning", text: "You're using Hannah Head's account"
    assert_accessible
    capture_screens("impersonating")

    within("x-banner") { click_on "Stop impersonating" }

    assert_current_path "/madmin"
    assert_no_selector "x-banner"
    assert_no_button "Stop impersonating"
  end
end
