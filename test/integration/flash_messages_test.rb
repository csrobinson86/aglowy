require "test_helper"

class FlashMessagesTest < ActionDispatch::IntegrationTest
  test "a redirect with a notice renders a dismissible Primer flash with the message, first in main" do
    sign_in identities(:head)

    post household_members_path(household_id: households(:home)), params: { member: { name: "Baby Head", role: "child" } }
    follow_redirect!

    assert_select "main .container-xl > .flash:first-child:not(.flash-error)", text: /\ABaby Head was added to the household\./ do
      assert_select ".octicon-info"
      assert_select "button.js-flash-close + tool-tip", "Dismiss alert"
    end
  end

  test "an alert renders the danger scheme" do
    sign_in identities(:spouse)

    post household_members_path(household_id: households(:home)), params: { member: { name: "Baby Head", role: "child" } }
    follow_redirect!

    assert_select "main .container-xl > .flash.flash-error:first-child", text: /\AYou can.t do that in this household\./ do
      assert_select ".octicon-alert"
      assert_select "button.js-flash-close"
    end
  end

  test "the application layout renders the flash first in main too" do
    post signup_path, params: { signup: { name: "Nina New", email: "nina@example.com", password: "password123", household_name: "The New Family", time_zone: "London" } }
    follow_redirect!

    assert_select "main", count: 1
    assert_select "main > .flash:first-child", text: /\ACheck your email to confirm your account\./ do
      assert_select ".octicon-info"
    end
  end

  test "flash text is escaped" do
    sign_in identities(:head)

    post household_members_path(household_id: households(:home)), params: { member: { name: "<b>Bold</b> & Co", role: "adult" } }
    follow_redirect!

    assert_select "main .flash b", count: 0
    assert_includes response.body, "&lt;b&gt;Bold&lt;/b&gt; &amp; Co was added to the household."
  end
end
