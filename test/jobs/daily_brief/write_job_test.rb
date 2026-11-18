require "test_helper"

# The job that writes a daily brief, and a pause stopping it before anything more is sent (docs/design/daily-brief.md,
# DailyBrief::Pause; Trap 12). No test calls a provider.
class DailyBrief::WriteJobTest < ActiveJob::TestCase
  setup do
    @user = users(:head)
    @user.accept_ai_terms(understood: "1")
    @plan = travel_to(3.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
    @writing = daily_brief_writing(DailyBrief.for(@user))
  end

  test "it writes the writing" do
    written = false
    DailyBrief::Writing.stub(:find_by, ->(id:) { @writing if id == @writing.id }) do
      @writing.stub(:write_now, -> { written = true }) { DailyBrief::WriteJob.perform_now(@writing.id) }
    end

    assert written
  end

  test "a writing that's gone is nothing to do" do
    @writing.daily_brief.destroy!

    assert_nothing_raised { DailyBrief::WriteJob.perform_now(@writing.id) }
  end

  test "a writing stopped by a pause before its job runs never calls the provider" do
    @plan.pause(reason: "chosen")

    run_job(ask: ->(*, **) { flunk "the AI was called" })

    assert_predicate @writing.reload, :stopped?
    assert Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "a pause during moderation ends it stopped without calling the provider" do
    run_job(flagged: ->(*) { @plan.pause(reason: "chosen")
                             false },
            ask: ->(*, **) { flunk "the AI was called" })

    assert_predicate @writing.reload, :stopped?
    assert Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "a plan paused before the job runs never calls moderation" do
    DailyBrief::Pause.create!(plan: @plan, reason: "chosen")

    run_job(flagged: ->(*) { flunk "moderation was called" }, ask: ->(*, **) { flunk "the AI was called" })

    assert_predicate @writing.reload, :stopped?
  end

  private
    def run_job(ask:, flagged: false)
      Ai::Moderation.stub(:flagged?, flagged) do
        @writing.chat.stub(:ask_within_purpose, ask) do
          DailyBrief::Writing.stub(:find_by, ->(id:) { @writing if id == @writing.id }) { DailyBrief::WriteJob.perform_now(@writing.id) }
        end
      end
    end
end
