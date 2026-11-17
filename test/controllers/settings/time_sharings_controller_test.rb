require "test_helper"

# Settings → Calendar, Share my times: the person's active households, each shared or not in one save
# (docs/design/calendar.md, Settings → Calendar). Hannah Head is a head in home and an adult in parents.
class Settings::TimeSharingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    sign_in identities(:head)
  end

  test "share with one household and stop with another in one save" do
    memberships(:head_in_parents).share_times

    patch household_settings_time_sharing_path(household_id: @home), params: { time_sharing: { household_ids: [ "", @home.id ] } }

    assert_redirected_to household_settings_calendar_path(household_id: @home)
    assert_equal "Sharing saved.", flash[:notice]
    assert memberships(:head_in_home).shares_times?
    assert_not memberships(:head_in_parents).shares_times?
  end

  test "a household the person isn't in is ignored" do
    patch household_settings_time_sharing_path(household_id: @home), params: { time_sharing: { household_ids: [ "", households(:other).id ] } }

    assert_redirected_to household_settings_calendar_path(household_id: @home)
    assert_not Membership::TimeSharing.exists?
  end

  test "nothing ticked stops sharing everywhere" do
    memberships(:head_in_home).share_times

    patch household_settings_time_sharing_path(household_id: @home), params: { time_sharing: { household_ids: [ "" ] } }

    assert_not memberships(:head_in_home).shares_times?
  end

  test "a child shares their own times" do
    sign_in identities(:eli)

    patch household_settings_time_sharing_path(household_id: @home), params: { time_sharing: { household_ids: [ "", @home.id ] } }

    assert memberships(:eli_in_home).shares_times?
  end

  test "a non-member gets a 404 and shares nothing" do
    sign_in identities(:outsider)

    patch household_settings_time_sharing_path(household_id: @home), params: { time_sharing: { household_ids: [ households(:other).id ] } }

    assert_response :not_found
    assert_not Membership::TimeSharing.exists?
  end
end
