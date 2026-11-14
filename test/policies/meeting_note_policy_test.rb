require "test_helper"

class MeetingNotePolicyTest < ActiveSupport::TestCase
  test "any active member can list and start their own notes, whatever their role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      policy = MeetingNotePolicy.new(memberships(membership), MeetingNote)

      assert policy.index? && policy.create?, "expected #{membership} to be let in"
    end
  end

  test "an inactive or nil membership can't list or start notes" do
    [ memberships(:former_in_home), nil ].each do |membership|
      policy = MeetingNotePolicy.new(membership, MeetingNote)

      assert_not policy.index? || policy.create?
    end
  end

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

  test "the author can share, through any household they're active in" do
    [ memberships(:head_in_home), memberships(:head_in_parents) ].each do |membership|
      assert MeetingNotePolicy.new(membership, meeting_notes(:head_midweek)).share?, "expected #{membership.household.name} to let the author share"
    end
  end

  test "nobody else can share, whatever their role, nor a nil membership" do
    %i[ spouse_in_home child_in_home grandparent_in_parents outsider_in_other ].each do |membership|
      assert_not MeetingNotePolicy.new(memberships(membership), meeting_notes(:head_midweek)).share?, "expected #{membership} to be refused"
    end
    assert_not MeetingNotePolicy.new(nil, meeting_notes(:head_midweek)).share?
  end

  test "the author through an inactive membership can't share" do
    memberships(:head_in_home).update_column(:active, false)

    assert_not MeetingNotePolicy.new(memberships(:head_in_home), meeting_notes(:head_midweek)).share?
  end

  test "any active member of a household the note is shared with can read it, whatever their role, but not change or share it" do
    meeting_notes(:head_midweek).share_with(households(:home))

    %i[ spouse_in_home child_in_home ].each do |membership|
      policy = MeetingNotePolicy.new(memberships(membership), meeting_notes(:head_midweek))

      assert policy.show?, "expected #{membership} to read it"
      assert_not policy.update? || policy.edit? || policy.destroy? || policy.share?, "expected #{membership} not to change it"
    end
  end

  test "a head of the household it's shared with can read it" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    note.share_with(households(:home))

    assert MeetingNotePolicy.new(memberships(:head_in_home), note).show?
  end

  test "a shared note can't be read through another household, an inactive membership or a nil membership" do
    meeting_notes(:head_midweek).share_with(households(:home))

    assert_not MeetingNotePolicy.new(memberships(:grandparent_in_parents), meeting_notes(:head_midweek)).show?
    assert_not MeetingNotePolicy.new(memberships(:outsider_in_other), meeting_notes(:head_midweek)).show?
    assert_not MeetingNotePolicy.new(memberships(:former_in_home), meeting_notes(:head_midweek)).show?
    assert_not MeetingNotePolicy.new(nil, meeting_notes(:head_midweek)).show?
  end

  test "a shared note can't be read once its author is no longer active in the household" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    note.share_with(households(:home))
    memberships(:spouse_in_home).update_column(:active, false)

    assert_not MeetingNotePolicy.new(memberships(:head_in_home), note).show?
  end
end
