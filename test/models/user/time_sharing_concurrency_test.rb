require "test_helper"

# Two Settings → Calendar saves by one person at the same moment: User#share_times_only_with takes the user's row
# lock, so the saves take turns and the result is one of the two selections, never both (docs/design/calendar.md,
# Settings → Calendar). Each thread needs its own committed view of the rows, so this test runs outside a transaction.
class User::TimeSharingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @head = users(:head)
    @home = households(:home)
    @parents = households(:parents)
  end

  # Fixtures are committed in this test, so take the head's sharing rows away for the tests that run after it.
  teardown do
    Membership::TimeSharing.where(membership: @head.memberships).delete_all
  end

  test "two saves at once leave one selection shared, not both" do
    selections = [ [ @home.id ], [ @parents.id ] ]
    ready = Concurrent::CountDownLatch.new(selections.size)
    go = Concurrent::CountDownLatch.new(1)

    threads = selections.map do |household_ids|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          user = User.find(@head.id)
          ready.count_down
          go.wait
          user.share_times_only_with(household_ids)
        end
      ensure
        ready.count_down # A thread that raised first still releases ready.wait; threads.map(&:value) re-raises.
      end
    end

    ready.wait
    go.count_down
    threads.each(&:value)

    assert_includes selections, @head.households_seeing_times.map(&:id)
  end
end
