require "test_helper"

# Heads and adults list, add, rename and delete categories in Settings → Go bags; children don't
# (docs/design/go-bags.md, Who can do what).
class GoBag::CategoryPolicyTest < ActiveSupport::TestCase
  ACTIONS = %i[ index? create? new? update? edit? destroy? ].freeze

  test "a head and an adult may do everything" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = GoBag::CategoryPolicy.new(memberships(membership), go_bag_categories(:water_food))

      ACTIONS.each { assert policy.public_send(it), "expected #{membership} to be allowed #{it}" }
    end
  end

  test "a child may not" do
    policy = GoBag::CategoryPolicy.new(memberships(:child_in_home), go_bag_categories(:water_food))

    ACTIONS.each { assert_not policy.public_send(it), "expected a child to be refused #{it}" }
  end

  test "no membership or an inactive one may not" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = GoBag::CategoryPolicy.new(membership, go_bag_categories(:water_food))

      ACTIONS.each { assert_not policy.public_send(it), "expected #{membership.inspect} to be refused #{it}" }
    end
  end
end
