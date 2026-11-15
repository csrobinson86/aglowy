require "test_helper"

class Identity::PasswordSetupTest < ActiveSupport::TestCase
  setup do
    @identity = identities(:eli)
    @token = @identity.generate_token_for(:password_setup)
  end

  test "finds the login from a fresh token, and nothing from a used, expired or missing one" do
    assert_equal @identity, Identity::PasswordSetup.new(token: @token).identity
    assert_nil Identity::PasswordSetup.new(token: nil).identity
    assert_nil Identity::PasswordSetup.new(token: "garbage").identity
  end

  test "a password set after the page was loaded but before saving makes the save fail" do
    setup = Identity::PasswordSetup.new(token: @token, password: "second-password", password_confirmation: "second-password")
    setup.identity

    Identity.find(@identity.id).update!(password: "first-password")

    assert_not setup.save
    assert @identity.reload.valid_password?("first-password")
  end
end
