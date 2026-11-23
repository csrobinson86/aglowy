require "test_helper"

# Every member sees the bags; heads and adults change them and see To buy (docs/design/go-bags.md, Who can do what).
class GoBagPolicyTest < ActiveSupport::TestCase
  WRITES = %i[ create? new? update? edit? destroy? shopping_list? ].freeze

  test "a head and an adult may do everything" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = GoBagPolicy.new(memberships(membership), go_bags(:family))

      assert policy.index? && policy.show?, "expected #{membership} to see bags"
      WRITES.each { assert policy.public_send(it), "expected #{membership} to be allowed #{it}" }
    end
  end

  test "a child may see the bags but change nothing and not see To buy" do
    policy = GoBagPolicy.new(memberships(:child_in_home), go_bags(:family))

    assert policy.index? && policy.show?
    WRITES.each { assert_not policy.public_send(it), "expected a child to be refused #{it}" }
  end

  test "no membership or an inactive one may do nothing" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = GoBagPolicy.new(membership, go_bags(:family))

      [ :index?, :show?, *WRITES ].each { assert_not policy.public_send(it), "expected #{membership.inspect} to be refused #{it}" }
    end
  end
end
