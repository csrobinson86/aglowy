require "test_helper"

# Heads and adults add, edit, remove and tick items; children only look (docs/design/go-bags.md, Who can do what).
class GoBag::ItemPolicyTest < ActiveSupport::TestCase
  ACTIONS = %i[ create? new? update? edit? destroy? ].freeze

  test "a head and an adult may do everything" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = GoBag::ItemPolicy.new(memberships(membership), go_bag_items(:water))

      ACTIONS.each { assert policy.public_send(it), "expected #{membership} to be allowed #{it}" }
    end
  end

  test "a child may not" do
    policy = GoBag::ItemPolicy.new(memberships(:child_in_home), go_bag_items(:water))

    ACTIONS.each { assert_not policy.public_send(it), "expected a child to be refused #{it}" }
  end

  test "no membership or an inactive one may not" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = GoBag::ItemPolicy.new(membership, go_bag_items(:water))

      ACTIONS.each { assert_not policy.public_send(it), "expected #{membership.inspect} to be refused #{it}" }
    end
  end
end
