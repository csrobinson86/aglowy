require "test_helper"

# Settings → Calendar, for every role (docs/design/calendar.md, Settings → Calendar; docs/design/settings.md).
class Settings::CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head, an adult and a child see Share my times with a box per active household, ticked where they share" do
    memberships(:head_in_parents).share_times

    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      get household_settings_calendar_path(household_id: @home)

      assert_response :success
      assert_select "main h2", "Calendar"
      assert_select "main", text: /Who sees your times, and your phone calendar link\./
      assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Calendar"
      assert_select "form[action=?] input[type=checkbox][name='time_sharing[household_ids][]'][value=?]",
                    household_settings_time_sharing_path(household_id: @home), @home.id
    end

    sign_in identities(:head)
    get household_settings_calendar_path(household_id: @home)
    assert_select "input[type=checkbox][value=?][checked]", households(:parents).id
    assert_select "input[type=checkbox][value=?]:not([checked])", @home.id
  end

  test "a household the person left isn't offered" do
    sign_in identities(:former)
    memberships(:former_in_home).update!(active: true)
    households(:parents).memberships.create!(user: users(:former), role: :adult, active: false)

    get household_settings_calendar_path(household_id: @home)

    assert_select "input[type=checkbox][value=?]", households(:parents).id, count: 0
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    get household_settings_calendar_path(household_id: @home)

    assert_response :not_found
  end
end
