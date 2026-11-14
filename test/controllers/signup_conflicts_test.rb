require "test_helper"

class SignupConflictsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  # Exercise real constraint failures with Signup owning the transaction.
  self.use_transactional_tests = false

  test "an email index conflict rolls back signup and renders an email error with 422" do
    email = identities(:head).email

    with_identity_conflict(-> { self.email = email }) do
      assert_no_difference %w[ Identity.count User.count Household.count Membership.count ] do
        assert_no_emails do
          post signup_path, params: { signup: valid_params }
        end
      end
    end

    assert_response :unprocessable_content
    assert_select "body", text: /Email has already been taken|has already been taken/
    assert_select "input[name='signup[password]']:not([value])"
  end

  test "an unrelated unique constraint violation is re-raised and rolls back signup" do
    user_id = identities(:head).user_id

    with_identity_conflict(-> { self.user_id = user_id }) do
      assert_no_difference %w[ Identity.count User.count Household.count Membership.count ] do
        assert_no_emails do
          error = assert_raises(ActiveRecord::RecordNotUnique) { Signup.new(valid_params).save }
          assert_equal "index_identities_on_user_id",
            error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
        end
      end
    end
  end

  private

  def valid_params
    { name: "Rosa Robinson", email: "rosa@example.com", password: "password123",
      household_name: "The Robinson Family", time_zone: "London" }
  end

  # Change a unique value after Devise's validation to reproduce the race at INSERT.
  def with_identity_conflict(callback)
    Identity.set_callback(:create, :before, callback)
    yield
  ensure
    Identity.skip_callback(:create, :before, callback)
  end
end
