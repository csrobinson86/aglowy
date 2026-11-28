require "test_helper"

class FamilyStudy::WriteDraftJobTest < ActiveJob::TestCase
  test "the job takes an id and calls write_now" do
    draft = family_study_draft

    assert_enqueued_with(job: FamilyStudy::WriteDraftJob, args: [ draft.id ]) { draft.write_later }

    Ai::Moderation.stub(:flagged?, true) { perform_enqueued_jobs }
    assert_predicate draft.reload, :flagged?
  end

  test "a draft deleted before the job ran is nothing to do" do
    draft = family_study_draft
    draft.write_later
    draft.delete

    assert_nothing_raised { perform_enqueued_jobs }
  end
end
