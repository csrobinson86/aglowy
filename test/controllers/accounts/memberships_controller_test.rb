require "test_helper"

class Accounts::MembershipsControllerTest < ActionDispatch::IntegrationTest
  test "a signed-out visitor is sent to sign in" do
    delete account_membership_path(memberships(:spouse_in_home))

    assert_redirected_to new_identity_session_path
    assert memberships(:spouse_in_home).reload.active?
  end

  test "an adult leaves and their membership is inactive" do
    sign_in identities(:spouse)

    assert_no_difference -> { Membership.count } do
      delete account_membership_path(memberships(:spouse_in_home))
    end

    assert_redirected_to households_path
    assert_equal "You left the The Head Family.", flash[:notice]
    assert_not memberships(:spouse_in_home).reload.active?
  end

  # Goal sharings arrive with "Share a personal goal" (#97), which adds its own step to Membership#deactivate.
  test "their meeting-note sharings into that household are gone" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    note.share_with(households(:home))
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:spouse)

    assert_difference -> { MeetingNote::Sharing.count }, -1 do
      delete account_membership_path(memberships(:spouse_in_home))
    end
    assert_empty note.reload.shared_households
  end

  test "their open goal steps there are released" do
    sign_in identities(:spouse)

    delete account_membership_path(memberships(:spouse_in_home))

    assert_empty goal_steps(:share_learned).reload.assignees
  end

  test "the last head is refused" do
    sign_in identities(:head)

    delete account_membership_path(memberships(:head_in_home))

    assert_redirected_to edit_account_path
    assert_equal "Make someone else a head before you leave.", flash[:alert]
    assert memberships(:head_in_home).reload.active?
  end

  test "a head leaves when another active head stays" do
    memberships(:spouse_in_home).update!(role: :head)
    sign_in identities(:head)

    delete account_membership_path(memberships(:head_in_home))

    assert_redirected_to households_path
    assert_not memberships(:head_in_home).reload.active?
  end

  test "a child is refused" do
    sign_in identities(:eli)

    delete account_membership_path(memberships(:eli_in_home))

    assert_redirected_to root_path
    assert memberships(:eli_in_home).reload.active?
  end

  test "someone else's membership id is 404" do
    sign_in identities(:spouse)

    delete account_membership_path(memberships(:outsider_in_other))
    assert_response :not_found

    sign_in identities(:spouse) # a raised 404 doesn't keep the Warden session in integration tests
    delete account_membership_path(memberships(:head_in_home))
    assert_response :not_found

    assert memberships(:outsider_in_other).reload.active?
    assert memberships(:head_in_home).reload.active?
  end

  test "a membership already left is 404" do
    sign_in identities(:former)

    delete account_membership_path(memberships(:former_in_home))

    assert_response :not_found
  end
end
