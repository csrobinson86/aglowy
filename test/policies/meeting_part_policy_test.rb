require "test_helper"

class MeetingPartPolicyTest < ActiveSupport::TestCase
  test "a head, an adult and a child can list and add their own parts" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |name|
      membership = memberships(name)

      assert MeetingPartPolicy.new(membership, MeetingPart).index?, "expected #{name} to list"
      assert MeetingPartPolicy.new(membership, membership.user.meeting_parts.new).create?, "expected #{name} to add one"
    end
  end

  test "an inactive or nil membership can't list or add parts" do
    [ memberships(:former_in_home), nil ].each do |membership|
      assert_not MeetingPartPolicy.new(membership, MeetingPart).index?
      assert_not MeetingPartPolicy.new(membership, users(:former).meeting_parts.new).create?
    end
  end

  test "the owner can show, edit and delete their part, whatever their role and from any household they're in" do
    { head_in_home: :head_conversation, head_in_parents: :head_conversation, spouse_in_home: :spouse_talk, eli_in_home: :eli_conversation }.each do |membership, part|
      policy = MeetingPartPolicy.new(memberships(membership), meeting_parts(part))

      assert policy.show? && policy.update? && policy.destroy?, "expected #{membership} to reach #{part}"
    end
  end

  test "another person's part: nobody else can show, edit or delete it, whatever their role, nor a nil membership" do
    [ memberships(:spouse_in_home), memberships(:child_in_home), memberships(:former_in_home), memberships(:grandparent_in_parents), nil ].each do |membership|
      policy = MeetingPartPolicy.new(membership, meeting_parts(:head_conversation))

      assert_not policy.show? || policy.update? || policy.destroy?, "expected #{membership&.user&.name || "nil"} to be kept out"
    end
  end

  test "a former member can't reach their own part through a household they left" do
    part = users(:former).meeting_parts.new

    assert_not MeetingPartPolicy.new(memberships(:former_in_home), part).show?
  end
end
