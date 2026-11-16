require "test_helper"

class Ai::AcceptancePolicyTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "create? for the signed-in person themselves, with no membership" do
    Current.identity = identities(:spouse)

    assert Ai::AcceptancePolicy.new(nil, users(:spouse)).create?
  end

  test "create? no for anyone else, and no when signed out" do
    Current.identity = identities(:spouse)
    assert_not Ai::AcceptancePolicy.new(nil, users(:head)).create?

    Current.reset
    assert_not Ai::AcceptancePolicy.new(nil, users(:head)).create?
  end
end
