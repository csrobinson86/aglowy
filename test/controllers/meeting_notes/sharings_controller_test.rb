require "test_helper"

class MeetingNotes::SharingsControllerTest < ActionDispatch::IntegrationTest
  test "the author shares into the current household" do
    sign_in identities(:head)

    assert_difference -> { MeetingNote::Sharing.count } do
      post sharing_path(meeting_notes(:head_midweek), households(:parents))
    end

    assert_redirected_to household_meeting_note_path(household_id: households(:parents), id: meeting_notes(:head_midweek))
    assert_equal "Shared with The Grandparent Family.", flash[:notice]
    assert_equal [ households(:parents) ], meeting_notes(:head_midweek).shared_households
  end

  test "another member can't share someone else's note (404)" do
    sign_in identities(:spouse)

    assert_no_difference -> { MeetingNote::Sharing.count } do
      post sharing_path(meeting_notes(:head_midweek), households(:home))
    end

    assert_response :not_found
  end

  test "another member can't stop sharing someone else's note (404)" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:spouse)

    assert_no_difference -> { MeetingNote::Sharing.count } do
      delete sharing_path(meeting_notes(:head_midweek), households(:home))
    end

    assert_response :not_found
  end

  test "the author can't share into a household they don't belong to (404)" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingNote::Sharing.count } do
      post sharing_path(meeting_notes(:head_midweek), households(:other))
    end

    assert_response :not_found
  end

  test "stop sharing deletes the record" do
    meeting_notes(:head_midweek).share_with(households(:home))
    meeting_notes(:head_midweek).share_with(households(:parents))
    sign_in identities(:head)

    assert_difference -> { MeetingNote::Sharing.count }, -1 do
      delete sharing_path(meeting_notes(:head_midweek), households(:home))
    end

    assert_redirected_to household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_midweek))
    assert_equal "Stopped sharing with The Head Family.", flash[:notice]
    assert_equal [ households(:parents) ], meeting_notes(:head_midweek).shared_households
  end

  private
    def sharing_path(note, household)
      household_meeting_note_sharing_path(household_id: household, meeting_note_id: note)
    end
end
