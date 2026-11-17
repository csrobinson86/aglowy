require "test_helper"

# Household invitations sent 5 days ago that are still pending and unexpired, to whoever sent them
# (docs/design/notifications.md, The kinds and Recurring jobs).
class Notification::InvitationFollowUpJobTest < ActiveJob::TestCase
  test "day 5 notifies the sender" do
    invitation = invite("newcomer@example.com", at: Time.utc(2026, 11, 12, 13))

    at_2_pm_on_november_17 { Notification::InvitationFollowUpJob.perform_now }

    notification = Notification.find_by!(subject: invitation)
    assert_equal users(:head), notification.user
    assert_equal households(:home), notification.household
    assert_equal "invitation_unaccepted:#{invitation.id}", notification.dedupe_key
  end

  test "day 4 doesn't, an expired invitation doesn't, an accepted one doesn't" do
    day_four = invite("luis.rivera@example.com", at: Time.utc(2026, 11, 13, 13))
    expired = invite("grandpa@example.com", at: Time.utc(2026, 11, 12, 13)).tap { it.update!(expires_at: Time.utc(2026, 11, 16)) }
    accepted = invite("newcomer@example.com", at: Time.utc(2026, 11, 12, 13))
    travel_to(Time.utc(2026, 11, 14)) { accept(accepted) }

    at_2_pm_on_november_17 { Notification::InvitationFollowUpJob.perform_now }

    assert_not Notification.exists?(subject_type: "Invitation", subject_id: [ day_four, expired, accepted ].map(&:id))
    assert_not Notification.exists?(kind: "invitation_unaccepted")
  end

  test "a day the job didn't run is caught up the next day" do
    invitation = invite("newcomer@example.com", at: Time.utc(2026, 11, 11, 13))

    at_2_pm_on_november_17 { Notification::InvitationFollowUpJob.perform_now }

    assert Notification.exists?(subject_type: "Invitation", subject_id: invitation.id)
  end

  test "accepting the invitation deletes its notification" do
    invitation = invite("newcomer@example.com", at: Time.utc(2026, 11, 12, 13))
    at_2_pm_on_november_17 { Notification::InvitationFollowUpJob.perform_now }

    at_2_pm_on_november_17 { accept(invitation) }

    assert_not Notification.exists?(subject_type: "Invitation", subject_id: invitation.id)
  end

  private
    def invite(email, at:)
      travel_to(at) { households(:home).invitations.create!(email:, invited_by: users(:head)) }
    end

    def accept(invitation)
      assert InvitationAcceptance.new(token: invitation.generate_token_for(:acceptance), identity: identities(:newcomer)).join
    end

    def at_2_pm_on_november_17(&)
      travel_to(Time.utc(2026, 11, 17, 14), &)
    end
end
