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

  test "the owner can edit, tag and remove their bookmark from any household they're in, whatever their role" do
    {
      head_in_home: bookmarks(:head_suffering_article),
      head_in_parents: bookmarks(:head_suffering_article),
      spouse_in_home: bookmarks(:spouse_ransom_article),
      child_in_home: users(:child).bookmarks.new
    }.each do |name, bookmark|
      policy = BookmarkPolicy.new(memberships(name), bookmark)

      assert policy.update? && policy.tag? && policy.destroy?, "expected #{name} to let the owner in"
    end
  end

  test "nobody else can, whatever their role, and nor can a nil membership" do
    [ memberships(:spouse_in_home), memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = BookmarkPolicy.new(membership, bookmarks(:head_suffering_article))

      assert_not policy.destroy? || policy.create? || policy.update? || policy.tag?
    end
  end

  test "a head can't touch another member's bookmark" do
    policy = BookmarkPolicy.new(memberships(:head_in_home), bookmarks(:spouse_ransom_article))

    assert_not policy.destroy? || policy.update? || policy.tag?
  end
end
