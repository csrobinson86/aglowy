require "test_helper"

class IdentityMailerTest < ActionMailer::TestCase
  setup do
    @identity = identities(:head)
  end

  test "it goes to the account's address from the app's sender" do
    email = IdentityMailer.existing_account(@identity)

    assert_equal [ "head@example.com" ], email.to
    assert_equal [ "hello@localhost" ], email.from
    assert_equal "You already have an Aglowy account", email.subject
  end

  test "the body links to sign in and to reset the password" do
    email = IdentityMailer.existing_account(@identity)

    [ email.html_part, email.text_part ].each do |part|
      body = part.decoded

      assert_includes body, "http://example.com/identities/sign_in", "#{part.mime_type} has no sign-in link"
      assert_includes body, "http://example.com/identities/password/new", "#{part.mime_type} has no reset link"
    end
  end

  # Whoever typed the address may not be its owner, and the email only says the account exists.
  test "the body says nothing else about the account" do
    email = IdentityMailer.existing_account(@identity)

    [ email.html_part, email.text_part ].each do |part|
      body = part.decoded

      assert_not_includes body, @identity.user.name, "#{part.mime_type} names the person"
      @identity.user.households.each do |household|
        assert_not_includes body, household.name, "#{part.mime_type} names #{household.name}"
      end
    end
  end

  test "a mailer preview exists" do
    assert_includes ActionMailer::Preview.all.map(&:preview_name), "identity_mailer"

    email = IdentityMailerPreview.call(:existing_account)

    assert_equal "You already have an Aglowy account", email.subject
  end
end
