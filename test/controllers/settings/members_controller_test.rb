require "test_helper"

# Settings → Members and roles: each member's role, and Remove, heads only (docs/design/settings.md). Changing a role is
# Members::RolesController and removing MembersController#destroy, which return here.
class Settings::MembersControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head sees each active member with their role and Remove" do
    sign_in identities(:head)

    get household_settings_members_path(household_id: @home)

    assert_response :success
    assert_select "title", "Members and roles · Settings · The Head Family · Aglowy"
    assert_select "main h2", "Members and roles"
    assert_select "main p", "The Head Family · heads only."
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Members and roles"
    assert_select "##{ActionView::RecordIdentifier.dom_id(memberships(:spouse_in_home))} form[action=?]",
                  household_member_role_path(household_id: @home, member_id: memberships(:spouse_in_home))
    assert_select "button[aria-label=?]", "Remove Sam Spouse"
    assert_no_match "Frances Former", response.body
  end

  test "an adult and a child are refused" do
    %i[ spouse eli ].each do |identity|
      sign_in identities(identity)

      get household_settings_members_path(household_id: @home)

      assert_redirected_to household_root_path(household_id: @home)
      assert_equal "You can't do that in this household.", flash[:alert]
    end
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    get household_settings_members_path(household_id: @home)

    assert_response :not_found
  end
end
