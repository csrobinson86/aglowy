require "test_helper"

# What every job gets: a recurring job's loop goes on past a record that fails, and a job whose record was deleted is
# dropped (CLAUDE.md, Background Jobs).
class ApplicationJobTest < ActiveJob::TestCase
  # Returns the households it got through.
  class EachHouseholdJob < ApplicationJob
    def perform(failing)
      [].tap do |done|
        each_reporting_failures(Household.all) do |household|
          raise "this one fails" if household == failing
          done << household
        end
      end
    end
  end

  class TouchJob < ApplicationJob
    def perform(user) = user.touch
  end

  test "each_reporting_failures reports the record that raises, with the job and the record's GlobalID, and still yields the rest" do
    failing, *rest = Household.order(:id).to_a

    done = nil
    report = assert_error_reported(RuntimeError) { done = EachHouseholdJob.perform_now(failing) }

    assert_equal({ job: "ApplicationJobTest::EachHouseholdJob", record: failing.to_gid.to_s }, report.context.slice(:job, :record))
    assert_equal rest, done
    assert_operator rest.size, :>=, 2
  end

  test "a job whose record was deleted before it ran is discarded" do
    user = User.create!(name: "Gone soon")
    TouchJob.perform_later(user)
    user.delete

    assert_nothing_raised { perform_enqueued_jobs }
    assert_no_enqueued_jobs
  end
end
