require "test_helper"

class SignupTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  FOUR_ROWS = %w[ Identity.count User.count Household.count Membership.count ]

  test "a valid sign-up creates exactly one Identity, User, Household and head Membership" do
    signup = Signup.new(valid_attributes)

    assert_difference FOUR_ROWS, 1 do
      assert signup.save
    end

    membership = Identity.find_by!(email: "rosa@example.com").user.memberships.sole
    assert membership.head?
    assert_equal "The Robinson Family", membership.household.name
    assert_equal "London", membership.household.time_zone
  end

  # Saying the email is taken would tell anyone who uses Aglowy, so it answers as a new email does and tells the owner
  # instead, as Devise's paranoid mode does (docs/design/users.md, gotcha 25).
  test "a taken email creates none of the four, saves, and mails the owner" do
    signup = Signup.new(valid_attributes.merge(email: identities(:head).email))

    assert_enqueued_email_with IdentityMailer, :existing_account, args: [ identities(:head) ] do
      assert_no_difference FOUR_ROWS do
        assert signup.save
      end
    end

    assert_empty signup.errors
  end

  test "a taken email in another case and with spaces around it is the same person" do
    signup = Signup.new(valid_attributes.merge(email: "  #{identities(:head).email.upcase} "))

    assert_enqueued_email_with IdentityMailer, :existing_account, args: [ identities(:head) ] do
      assert_no_difference FOUR_ROWS do
        assert signup.save
      end
    end
  end

  # They never confirmed, so what they need to get in is the confirmation link.
  test "an unconfirmed owner gets the confirmation instructions again" do
    signup = Signup.new(valid_attributes.merge(email: identities(:newcomer).email))

    assert_no_enqueued_emails do
      assert_no_difference FOUR_ROWS do
        assert_emails 1 do
          assert signup.save
        end
      end
    end

    assert_empty signup.errors
    assert_equal [ identities(:newcomer).email ], ActionMailer::Base.deliveries.last.to
    assert_equal "Confirmation instructions", ActionMailer::Base.deliveries.last.subject
  end

  test "a taken email with a short password fails with the password error alone and sends nothing" do
    signup = Signup.new(valid_attributes.merge(email: identities(:head).email, password: "abc"))

    assert_no_enqueued_emails do
      assert_no_emails do
        assert_not signup.save
      end
    end

    assert_equal [ :password ], signup.errors.attribute_names
  end

  # The User allows a blank time zone and the Household doesn't, so the Household fails, before the Identity is
  # written: a taken email can't skip past it to a success.
  test "a taken email with a blank time zone fails just as a new one does, and sends nothing" do
    answers = [ identities(:head).email, "rosa@example.com" ].map do |email|
      signup = Signup.new(valid_attributes.merge(email:, time_zone: ""))

      assert_no_enqueued_emails do
        assert_no_emails do
          assert_no_difference FOUR_ROWS do
            assert_not signup.save
          end
        end
      end

      signup.errors.to_hash
    end

    assert_equal({ time_zone: [ "is not included in the list" ] }, answers.first)
    assert_equal answers.first, answers.last
  end

  # Two sign-ups racing for one email both pass Devise's uniqueness check in
  # Ruby; the unique index stops the second (docs/design/users.md, gotcha 3).
  test "a sign-up that loses the race for an email saves and mails the owner, not an exception" do
    signup = Signup.new(valid_attributes.merge(email: identities(:head).email))
    uniqueness = Identity.validators_on(:email).grep(ActiveRecord::Validations::UniquenessValidator).sole

    uniqueness.define_singleton_method(:validate) { |_record| }

    assert_enqueued_email_with IdentityMailer, :existing_account, args: [ identities(:head) ] do
      assert_no_difference FOUR_ROWS do
        assert signup.save
      end
    end

    assert_empty signup.errors
  ensure
    uniqueness.singleton_class.remove_method(:validate)
  end

  test "a missing household name is invalid and creates nothing" do
    signup = Signup.new(valid_attributes.merge(household_name: ""))

    assert_no_difference FOUR_ROWS do
      assert_not signup.save
    end

    assert_includes signup.errors[:household_name], "can't be blank"
  end

  test "a valid sign-up sends one confirmation email" do
    assert_emails 1 do
      Signup.new(valid_attributes).save
    end
  end

  # The User refuses an unknown time zone, so nothing is written and no mail goes out.
  test "an invalid sign-up sends none" do
    signup = Signup.new(valid_attributes.merge(time_zone: "Mars/Olympus Mons"))

    assert_no_emails do
      assert_not signup.save
    end

    assert_includes signup.errors[:time_zone], "is not included in the list"
  end

  private

  def valid_attributes
    { name: "Rosa Robinson", email: "rosa@example.com", password: "password123",
      household_name: "The Robinson Family", time_zone: "London" }
  end
end
