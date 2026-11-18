require "test_helper"

class DailyBriefPolicyTest < ActiveSupport::TestCase
  ACTIONS = %i[ index? show? new? create? edit? update? destroy? ].freeze

  test "a head and an adult may do everything with their own daily brief" do
    %i[ head_in_home spouse_in_home head_in_parents ].each do |name|
      policy = DailyBriefPolicy.new(memberships(name), :daily_brief)

      ACTIONS.each { |action| assert policy.public_send(action), "expected #{name} to #{action}" }
    end
  end

  test "a child may do nothing" do
    policy = DailyBriefPolicy.new(memberships(:eli_in_home), :daily_brief)

    ACTIONS.each { |action| assert_not policy.public_send(action), "expected a child not to #{action}" }
  end

  test "a child here who is an adult elsewhere has their brief from here too: it's the person's" do
    Membership.create!(household: households(:parents), user: users(:eli), role: :adult)
    policy = DailyBriefPolicy.new(memberships(:eli_in_home), :daily_brief)

    ACTIONS.each { |action| assert policy.public_send(action), "expected #{action}" }
  end

  test "no membership, or one that's ended, may do nothing" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = DailyBriefPolicy.new(membership, :daily_brief)

      ACTIONS.each { |action| assert_not policy.public_send(action), "expected #{membership.inspect} not to #{action}" }
    end
  end
end
