require "test_helper"

class PersonalNotePolicyTest < ActiveSupport::TestCase
  test "any active member can list and write their own notes, whatever their role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |name|
      membership = memberships(name)

      assert PersonalNotePolicy.new(membership, PersonalNote).index?, "expected #{name} to list"
      assert PersonalNotePolicy.new(membership, membership.user.personal_notes.new).create?, "expected #{name} to write one"
    end
  end

  test "an inactive or nil membership can't list or write notes" do
    [ memberships(:former_in_home), nil ].each do |membership|
      assert_not PersonalNotePolicy.new(membership, PersonalNote).index?
      assert_not PersonalNotePolicy.new(membership, users(:former).personal_notes.new).create?
    end
  end

  test "the owner can show, change, delete and tag their note from any household they're in" do
    [ memberships(:head_in_home), memberships(:head_in_parents) ].each do |membership|
      policy = PersonalNotePolicy.new(membership, personal_notes(:head_daniel))

      assert policy.show? && policy.update? && policy.destroy? && policy.tag? && policy.pin?, "expected #{membership.household.name} to let the owner in"
    end
  end

  test "nobody else can, whatever their role, and nor can a nil membership" do
    [ memberships(:spouse_in_home), memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = PersonalNotePolicy.new(membership, personal_notes(:head_daniel))

      assert_not policy.show? || policy.update? || policy.destroy? || policy.tag? || policy.pin? || policy.create?
    end
  end
end
