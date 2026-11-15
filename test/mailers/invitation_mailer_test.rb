require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  setup do
    @invitation = invitations(:ana)
    @invitation.household.update!(name: "Rivera household", time_zone: "Pacific Time (US & Canada)")
    @invitation.invited_by.update!(name: "Daniel Rivera")
    @invitation.update!(expires_at: Time.utc(2026, 11, 22, 3))
  end

  test "it goes to the invited address from the app's sender" do
    email = InvitationMailer.with(invitation: @invitation).invite

    assert_equal [ "ana.ortiz@example.com" ], email.to
    assert_equal [ "hello@localhost" ], email.from
  end

  test "subject names the inviter and household" do
    email = InvitationMailer.with(invitation: @invitation).invite

    assert_equal "Daniel Rivera invited you to the Rivera household on Aglowy", email.subject
  end

  test "the body has the accept link, the deadline and the address" do
    email = InvitationMailer.with(invitation: @invitation).invite

    [ email.html_part, email.text_part ].each do |part|
      body = part.decoded
      token = body[%r{http://example\.com/invitation\?token=([^"\s]+)}, 1]

      assert_equal @invitation, Invitation.find_acceptable(CGI.unescapeHTML(token)), "#{part.mime_type} has no working accept link"
      assert_includes body, "November 21", "#{part.mime_type} shows the deadline in the household's time zone"
      assert_includes body, "ana.ortiz@example.com"
    end

    assert_includes email.html_part.decoded, "Accept the invitation"
  end

  test "an invitation deleted before the job runs sends nothing and doesn't fail the job" do
    @invitation.deliver_later
    @invitation.destroy!

    assert_nothing_raised { perform_enqueued_jobs }
    assert_no_emails
  end

  test "a mailer preview exists" do
    assert_includes ActionMailer::Preview.all.map(&:preview_name), "invitation_mailer"

    email = InvitationMailerPreview.call(:invite)

    assert_equal "Maria Rivera invited you to the Rivera household on Aglowy", email.subject
  end

  test "Devise sends from the same address" do
    assert_equal "Aglowy <hello@localhost>", Devise.mailer_sender
  end
end
