require "test_helper"

# Any active member manages their own times; finding them through Current.user keeps others out
# (docs/design/calendar.md, Who can do what).
class PersonalTimePolicyTest < ActiveSupport::TestCase
  test "a head, an adult and a child may create, update and destroy" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      policy = PersonalTimePolicy.new(memberships(membership), PersonalTime.new)

      assert policy.create? && policy.new? && policy.update? && policy.edit? && policy.destroy?, "expected #{membership} to manage their times"
    end
  end

  test "no membership or an inactive one may not" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = PersonalTimePolicy.new(membership, PersonalTime.new)

      assert_not policy.create? || policy.update? || policy.destroy?, "expected #{membership.inspect} to be refused"
    end
  end
end
