require "test_helper"

class HouseholdPolicyTest < ActiveSupport::TestCase
  test "index? is true with a nil membership" do
    assert HouseholdPolicy.new(nil, Household).index?
  end

  test "index? is true for every role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert HouseholdPolicy.new(memberships(membership), Household).index?, "expected #{membership} to list households"
    end
  end

  # Starting a household asks about the person who'd be its head, the record; the membership is nil outside a household.
  test "create? follows can_start_household?" do
    %i[ head spouse former newcomer child eli ].each do |name|
      user = users(name)
      policy = HouseholdPolicy.new(nil, user)

      assert_equal user.can_start_household?, policy.create?, "expected create? for #{name} to follow can_start_household?"
      assert_equal user.can_start_household?, policy.new?, "expected new? for #{name} to follow can_start_household?"
    end
  end

  test "create? is true for heads and adults and false for children, whatever the membership" do
    [ nil, memberships(:head_in_home), memberships(:spouse_in_home), memberships(:child_in_home) ].each do |membership|
      assert HouseholdPolicy.new(membership, users(:head)).create?
      assert HouseholdPolicy.new(membership, users(:spouse)).create?
      assert_not HouseholdPolicy.new(membership, users(:eli)).create?
      assert_not HouseholdPolicy.new(membership, users(:child)).create?
    end
  end

  test "show? yes for head, adult and child" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert HouseholdPolicy.new(memberships(membership), households(:home)).show?, "expected #{membership} to see home"
    end
  end

  test "show? no for a nil membership" do
    assert_not HouseholdPolicy.new(nil, households(:home)).show?
  end

  test "show? no for an inactive membership" do
    assert_not HouseholdPolicy.new(memberships(:former_in_home), households(:home)).show?
  end

  test "show? no for a membership in another household" do
    assert_not HouseholdPolicy.new(memberships(:outsider_in_other), households(:home)).show?
  end

  test "update? yes for a head of the household" do
    assert HouseholdPolicy.new(memberships(:head_in_home), households(:home)).update?
  end

  # Household settings opens to adults for its Meetings section; the name and time zone stay heads only
  # (docs/design/meeting-helper.md, Trap 10).
  test "edit? and manage_meetings? yes for a head and an adult" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = HouseholdPolicy.new(memberships(membership), households(:home))

      assert policy.edit?, "expected #{membership} to open settings"
      assert policy.manage_meetings?, "expected #{membership} to set the meeting times"
    end
  end

  test "edit? and manage_meetings? no for a child" do
    policy = HouseholdPolicy.new(memberships(:child_in_home), households(:home))

    assert_not policy.edit?
    assert_not policy.manage_meetings?
  end

  test "edit? and manage_meetings? no for a nil membership, an inactive one, or a member of another household" do
    [ nil, memberships(:former_in_home), memberships(:outsider_in_other) ].each do |membership|
      policy = HouseholdPolicy.new(membership, households(:home))

      assert_not policy.edit?, "expected #{membership&.id.inspect} not to open settings"
      assert_not policy.manage_meetings?, "expected #{membership&.id.inspect} not to set the meeting times"
    end
  end

  test "update? no for an adult or a child" do
    %i[ spouse_in_home child_in_home ].each do |membership|
      assert_not HouseholdPolicy.new(memberships(membership), households(:home)).update?, "expected #{membership} not to edit settings"
    end
  end

  test "update? no for a nil membership, an inactive one, or a head of another household" do
    assert_not HouseholdPolicy.new(nil, households(:home)).update?
    memberships(:head_in_home).update_column(:active, false)
    assert_not HouseholdPolicy.new(memberships(:head_in_home), households(:home)).update?
    assert_not HouseholdPolicy.new(memberships(:outsider_in_other), households(:home)).update?
  end
end
