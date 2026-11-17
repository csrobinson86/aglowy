require "test_helper"

# Settings → My households (docs/design/settings.md, Pages and routes, Leaving).
class Settings::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head, an adult and a child see their households with their role" do
    { head: [ "The Grandparent Family", "The Head Family" ], spouse: [ "The Head Family" ], eli: [ "The Head Family" ] }.each do |identity, households|
      sign_in identities(identity)

      get household_settings_memberships_path(household_id: @home)

      assert_response :success
      assert_select "main h2", "My households"
      assert_select "main", text: /The households you belong to\./
      assert_select "nav[aria-label='Settings'] a[aria-current=page]", "My households"
      assert_equal households, css_select("main .Box-row .Truncate-text").map { it.text.strip }
    end
  end

  test "a child sees no Leave" do
    sign_in identities(:eli)

    get household_settings_memberships_path(household_id: @home)

    assert_select "main", text: /Child/
    assert_select "button[aria-label^=Leave]", count: 0
  end

  test "Leave posts to Settings" do
    sign_in identities(:head)

    get household_settings_memberships_path(household_id: @home)

    assert_select "form[action=?]", household_settings_membership_path(household_id: @home, id: memberships(:head_in_parents))
  end

  test "leaving the household in the URL goes to the households page" do
    sign_in identities(:spouse)

    delete household_settings_membership_path(household_id: @home, id: memberships(:spouse_in_home))

    assert_redirected_to households_path
    assert_equal "You left the The Head Family.", flash[:notice]
    assert_not memberships(:spouse_in_home).reload.active?
  end

  test "leaving another household returns to My households" do
    sign_in identities(:head)

    delete household_settings_membership_path(household_id: @home, id: memberships(:head_in_parents))

    assert_redirected_to household_settings_memberships_path(household_id: @home)
    assert_equal "You left the The Grandparent Family.", flash[:notice]
    assert_not memberships(:head_in_parents).reload.active?
  end

  test "the last head can't leave" do
    sign_in identities(:head)

    delete household_settings_membership_path(household_id: @home, id: memberships(:head_in_home))

    assert_redirected_to household_settings_memberships_path(household_id: @home)
    assert_equal "Make someone else a head before you leave.", flash[:alert]
    assert memberships(:head_in_home).reload.active?
  end

  test "a child can't leave" do
    sign_in identities(:eli)

    delete household_settings_membership_path(household_id: @home, id: memberships(:eli_in_home))

    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]
    assert memberships(:eli_in_home).reload.active?
  end

  test "someone else's seat is a 404" do
    sign_in identities(:spouse)

    delete household_settings_membership_path(household_id: @home, id: memberships(:head_in_home))

    assert_response :not_found
    assert memberships(:head_in_home).reload.active?
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)
    get household_settings_memberships_path(household_id: @home)
    assert_response :not_found

    sign_in identities(:outsider)
    delete household_settings_membership_path(household_id: @home, id: memberships(:outsider_in_other))
    assert_response :not_found
    assert memberships(:outsider_in_other).reload.active?
  end
end
