require "test_helper"

# Another angle, Try again, Write it with AI, the progress frame and Stop (docs/design/daily-brief.md, How a writing
# runs; The brief, its states). Tuesday 17 November 2026, 9:00 AM in Hannah's zone. The job is only queued: nothing here
# calls an AI provider.
class DailyBriefs::WritingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @home = households(:home)
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    @user.accept_ai_terms(understood: "1")
    travel_to Time.utc(2026, 11, 17, 15)
    travel_to(3.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
    @brief = DailyBrief.for(@user)
    sign_in identities(:head)
  end

  test "create starts one, with its job, and goes back to the brief" do
    assert_difference(-> { @brief.writings.count }, 1) do
      assert_enqueued_jobs(1, only: DailyBrief::WriteJob) { post household_daily_brief_writings_path(household_id: @home) }
    end

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_predicate @brief.writings.sole, :writing?
  end

  test "Write it with AI passes first, so a brief with a writing already isn't written again" do
    daily_brief_writing(@brief, status: "failed")

    assert_no_difference(-> { DailyBrief::Writing.count }) { post household_daily_brief_writings_path(household_id: @home, first: true) }

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_equal "This brief has been written already.", flash[:alert]
  end

  test "at the day's 3 it answers No more today and starts none" do
    3.times { Ai::Use.create!(user: @user, purpose: "daily_brief") }

    assert_no_starting { post household_daily_brief_writings_path(household_id: @home) }

    assert_equal "No more today.", flash[:alert]
  end

  test "with 6 writings of the brief, whatever their endings, it answers No more today and starts none" do
    6.times { daily_brief_writing(@brief, status: "failed", use: nil) }

    assert_no_starting { post household_daily_brief_writings_path(household_id: @home) }

    assert_equal "No more today.", flash[:alert]
  end

  test "a child is refused and starts none" do
    sign_in identities(:eli)

    assert_no_starting { post household_daily_brief_writings_path(household_id: @home) }

    assert_redirected_to household_root_path(household_id: @home)
  end

  test "without the AI terms it says why and starts none" do
    @user.ai_acceptances.delete_all

    assert_no_starting { post household_daily_brief_writings_path(household_id: @home) }

    assert_equal "Only you, as a head or adult with AI drafts turned on, can have your brief written.", flash[:alert]
  end

  test "while one is being written it says so and starts none" do
    daily_brief_writing(@brief)

    assert_no_starting { post household_daily_brief_writings_path(household_id: @home) }

    assert_equal "This brief is being written.", flash[:alert]
  end

  test "with no brief today it's a 404" do
    @brief.destroy!

    post household_daily_brief_writings_path(household_id: @home)

    assert_response :not_found
  end

  test "show is the progress frame while writing: the lines and Stop, never the text" do
    writing = daily_brief_writing(@brief, result: { "thread" => "Not to be shown." })

    get household_daily_brief_writing_path(household_id: @home, id: writing)

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(writing)}" do
      assert_select "li", text: /Searching jw.org and wol.jw.org/
      assert_select "form[action=?] button", household_daily_brief_writing_path(household_id: @home, id: writing), "Stop"
    end
    assert_no_match "Not to be shown.", response.body
  end

  test "show as a Turbo Stream says nothing while writing, and refreshes the page once it's finished" do
    writing = daily_brief_writing(@brief)

    get household_daily_brief_writing_path(household_id: @home, id: writing), as: :turbo_stream
    assert_response :no_content

    writing.update!(status: "written", result: { "thread" => "Done." })
    get household_daily_brief_writing_path(household_id: @home, id: writing), as: :turbo_stream
    assert_select "turbo-stream[action=refresh]"
  end

  test "destroy stops a writing one, which keeps its use" do
    writing = daily_brief_writing(@brief)

    delete household_daily_brief_writing_path(household_id: @home, id: writing)

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_predicate writing.reload, :stopped?
    assert Ai::Use.exists?(daily_brief_writing_id: writing.id)
  end

  test "destroy changes nothing on a finished one" do
    writing = daily_brief_writing(@brief, status: "written", result: { "thread" => "Kept." })

    delete household_daily_brief_writing_path(household_id: @home, id: writing)

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_predicate writing.reload, :written?
    assert_equal({ "thread" => "Kept." }, writing.result)
  end

  test "another person's writing is a 404" do
    spouse = users(:spouse)
    spouse.accept_ai_terms(understood: "1")
    DailyBrief::Plan.start(spouse, starter: "basics")
    writing = daily_brief_writing(DailyBrief.for(spouse))

    get household_daily_brief_writing_path(household_id: @home, id: writing)
    assert_response :not_found

    sign_in identities(:head) # The test's sign-in doesn't outlast a 404.
    delete household_daily_brief_writing_path(household_id: @home, id: writing)
    assert_response :not_found
    assert_predicate writing.reload, :writing?
  end

  private
    def assert_no_starting(&)
      assert_no_difference(-> { DailyBrief::Writing.count }) { assert_no_enqueued_jobs(only: DailyBrief::WriteJob, &) }
    end
end
