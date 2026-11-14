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

  # From the page, Turbo asks for streams: the label, the button and the save hint change in place, so
  # sharing from the edit page keeps what the author hasn't saved yet.
  test "sharing from the page updates it in place" do
    sign_in identities(:head)

    post sharing_path(meeting_notes(:head_midweek), households(:home)), as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: :replace, target: "meeting-note-sharing-label" do
      assert_select ".Label", text: "Shared with The Head Family"
    end
    assert_turbo_stream action: :update, target: "meeting-note-sharing" do
      assert_select "button", text: "Stop sharing"
    end
    assert_turbo_stream(action: :update, target: "meeting-note-save-hint") { assert_select "template", text: "Members of The Head Family can read this note." }
    assert_turbo_stream action: :remove, targets: "main .flash:not(.Banner)"
    assert_turbo_stream(action: :prepend, targets: "main .container-xl") { assert_select "template", text: /Shared with The Head Family\./ }
  end

  # turbo_stream.update marks a String html_safe, so a household's name reaches the hint as text only if escaped.
  test "sharing from the page shows the household's name as text" do
    households(:home).update!(name: "<img src=x onerror=alert(1)>")
    sign_in identities(:head)

    post sharing_path(meeting_notes(:head_midweek), households(:home)), as: :turbo_stream

    assert_turbo_stream(action: :update, target: "meeting-note-save-hint") do
      assert_select "template img", count: 0
      assert_select "template", text: "Members of <img src=x onerror=alert(1)> can read this note."
    end
  end

  test "stopping from the page updates it in place" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:head)

    delete sharing_path(meeting_notes(:head_midweek), households(:home)), as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: :replace, target: "meeting-note-sharing-label" do
      assert_select ".Label", text: "Private"
    end
    assert_turbo_stream action: :update, target: "meeting-note-sharing" do
      assert_select "button", text: "Share with household"
    end
    assert_turbo_stream(action: :update, target: "meeting-note-save-hint") { assert_select "template", text: "Only you can see this note." }
    assert_turbo_stream action: :remove, targets: "main .flash:not(.Banner)"
    assert_turbo_stream(action: :prepend, targets: "main .container-xl") { assert_select "template", text: /Stopped sharing with The Head Family\./ }
  end

  private
    def sharing_path(note, household)
      household_meeting_note_sharing_path(household_id: household, meeting_note_id: note)
    end
end
