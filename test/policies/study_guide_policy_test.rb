require "test_helper"

# A study guide is its owner's alone, read under a head or adult membership in the household in the URL
# (docs/design/study-guide.md, Who can do what; Pages and routes, StudyGuidePolicy).
class StudyGuidePolicyTest < ActiveSupport::TestCase
  test "a head and an adult may read their own study guide" do
    { head_in_home: study_guides(:head_nov_9), spouse_in_home: StudyGuide.new(user: users(:spouse)) }.each do |name, guide|
      assert StudyGuidePolicy.new(memberships(name), :study_guide).index?, "expected #{name} to list their guides"
      assert StudyGuidePolicy.new(memberships(name), guide).show?, "expected #{name} to read their own guide"
    end
  end

  test "another person's guide, no" do
    assert_not StudyGuidePolicy.new(memberships(:spouse_in_home), study_guides(:head_nov_9)).show?
  end

  test "a child membership, no, even for their own guide or when they're an adult in another household" do
    Membership.create!(household: households(:parents), user: users(:eli), role: :adult)
    policy = StudyGuidePolicy.new(memberships(:eli_in_home), StudyGuide.new(user: users(:eli)))

    assert_not policy.index?
    assert_not policy.show?
  end

  test "no membership, or one that's ended, no" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      assert_not StudyGuidePolicy.new(membership, :study_guide).index?
      assert_not StudyGuidePolicy.new(membership, StudyGuide.new(user: users(:former))).show?
    end
  end
end
