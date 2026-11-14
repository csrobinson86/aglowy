require "test_helper"

class MeetingNotePolicyTest < ActiveSupport::TestCase
  test "the author can show, update and destroy" do
    [ memberships(:head_in_home), memberships(:head_in_parents) ].each do |membership|
      policy = MeetingNotePolicy.new(membership, meeting_notes(:head_midweek))

      assert policy.show? && policy.update? && policy.edit? && policy.destroy?, "expected #{membership.household.name} to let the author in"
    end
  end

  test "another member of the same household can't, whatever their role" do
    %i[ spouse_in_home child_in_home ].each do |membership|
      policy = MeetingNotePolicy.new(memberships(membership), meeting_notes(:head_midweek))

      assert_not policy.show? || policy.update? || policy.destroy?, "expected #{membership} to be refused"
    end
  end

  test "a member of another household the author is in can't" do
    policy = MeetingNotePolicy.new(memberships(:grandparent_in_parents), meeting_notes(:head_midweek))

    assert_not policy.show? || policy.update? || policy.destroy?
  end

  test "someone who shares no household with the author can't" do
    policy = MeetingNotePolicy.new(memberships(:outsider_in_other), meeting_notes(:head_midweek))

    assert_not policy.show? || policy.update? || policy.destroy?
  end

  test "a nil membership can't" do
    policy = MeetingNotePolicy.new(nil, meeting_notes(:head_midweek))

    assert_not policy.show? || policy.update? || policy.destroy?
  end

  test "the author through an inactive membership can't" do
    memberships(:head_in_home).update_column(:active, false)
    policy = MeetingNotePolicy.new(memberships(:head_in_home), meeting_notes(:head_midweek))

    assert_not policy.show? || policy.update? || policy.destroy?
  end
end
