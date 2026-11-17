require "test_helper"

class Memberships::StudyAiGrantsControllerTest < ActionDispatch::IntegrationTest
  test "a head turns it on and off, and comes back to the Children section" do
    sign_in identities(:head)

    post household_membership_study_ai_grant_path(household_id: households(:home), membership_id: memberships(:eli_in_home))

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home), anchor: "children")
    assert_equal "Personal study with AI turned on for Eli Child.", flash[:notice]
    assert_equal users(:head), memberships(:eli_in_home).reload.study_ai_grant.granted_by

    delete household_membership_study_ai_grant_path(household_id: households(:home), membership_id: memberships(:eli_in_home))

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home), anchor: "children")
    assert_equal "Personal study with AI turned off for Eli Child.", flash[:notice]
    assert_not memberships(:eli_in_home).reload.study_ai_grant?
  end

  test "a child without a login is refused with the reason" do
    sign_in identities(:head)

    post household_membership_study_ai_grant_path(household_id: households(:home), membership_id: memberships(:sofia_in_home))

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home), anchor: "children")
    assert_equal "Sofia Child needs a login first.", flash[:alert]
    assert_not memberships(:sofia_in_home).reload.study_ai_grant?
  end

  test "an adult can't" do
    sign_in identities(:spouse)

    post household_membership_study_ai_grant_path(household_id: households(:home), membership_id: memberships(:eli_in_home))

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_not memberships(:eli_in_home).reload.study_ai_grant?
  end

  test "an adult's seat, or another household's child, is a 404" do
    sign_in identities(:head)

    post household_membership_study_ai_grant_path(household_id: households(:home), membership_id: memberships(:spouse_in_home))
    assert_response :not_found

    eli_in_other = Membership.create!(household: households(:other), user: users(:eli), role: :child)
    sign_in identities(:head)
    post household_membership_study_ai_grant_path(household_id: households(:home), membership_id: eli_in_other)
    assert_response :not_found
  end
end
