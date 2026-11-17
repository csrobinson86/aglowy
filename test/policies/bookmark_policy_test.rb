require "test_helper"

# Bookmarks are their owner's alone, whatever their role (docs/design/bookmarks.md: private, like everything in Mine).
class BookmarkPolicyTest < ActiveSupport::TestCase
  test "any active member can list and save their own bookmarks, whatever their role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |name|
      membership = memberships(name)

      assert BookmarkPolicy.new(membership, Bookmark).index?, "expected #{name} to list"
      assert BookmarkPolicy.new(membership, membership.user.bookmarks.new).create?, "expected #{name} to save one"
    end
  end

  test "an inactive or nil membership can't list or save bookmarks" do
    [ memberships(:former_in_home), nil ].each do |membership|
      assert_not BookmarkPolicy.new(membership, Bookmark).index?
      assert_not BookmarkPolicy.new(membership, users(:former).bookmarks.new).create?
    end
  end

  test "the owner can remove their bookmark from any household they're in" do
    [ memberships(:head_in_home), memberships(:head_in_parents) ].each do |membership|
      assert BookmarkPolicy.new(membership, bookmarks(:head_suffering_article)).destroy?, "expected #{membership.household.name} to let the owner in"
    end
  end

  test "nobody else can, whatever their role, and nor can a nil membership" do
    [ memberships(:spouse_in_home), memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = BookmarkPolicy.new(membership, bookmarks(:head_suffering_article))

      assert_not policy.destroy? || policy.create?
    end
  end
end
