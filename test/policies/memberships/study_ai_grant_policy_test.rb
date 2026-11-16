require "test_helper"

class Memberships::StudyAiGrantPolicyTest < ActiveSupport::TestCase
  test "a head here: yes" do
    policy = Memberships::StudyAiGrantPolicy.new(memberships(:head_in_home), memberships(:eli_in_home))

    assert policy.create?
    assert policy.destroy?
  end

  test "an adult, a child and a non-member: no" do
    [ memberships(:spouse_in_home), memberships(:eli_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = Memberships::StudyAiGrantPolicy.new(membership, memberships(:eli_in_home))

      assert_not policy.create? || policy.destroy?, "expected #{membership&.user&.name.inspect} not to"
    end
  end

  test "a head of another household: no" do
    policy = Memberships::StudyAiGrantPolicy.new(memberships(:outsider_in_other), memberships(:eli_in_home))

    assert_not policy.create? || policy.destroy?
  end
end
