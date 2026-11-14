require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  test "setting identity sets user" do
    Current.identity = identities(:head)

    assert_equal users(:head), Current.user
  end

  test "setting membership sets household" do
    Current.membership = memberships(:head_in_home)

    assert_equal households(:home), Current.household
  end
end
