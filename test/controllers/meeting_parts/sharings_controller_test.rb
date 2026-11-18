require "test_helper"

# Sharing a part with the household in the URL, and stopping (docs/design/meeting-parts.md, Sharing).
class MeetingParts::SharingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @part = meeting_parts(:head_conversation)
  end

  test "the owner shares into the current household" do
    sign_in identities(:head)

    assert_difference -> { MeetingPart::Sharing.count } do
      post sharing_path(@part, households(:parents))
    end

    assert_redirected_to household_meeting_part_path(household_id: households(:parents), id: @part)
    assert_equal "Shared with The Grandparent Family.", flash[:notice]
    assert_equal [ households(:parents) ], @part.shared_households
    assert_equal [ users(:grandparent) ], Notification.where(subject: @part).map(&:user)
  end

  test "the owner stops sharing, in the current household only" do
    @part.share_with(households(:home))
    @part.share_with(households(:parents))
    sign_in identities(:head)

    assert_difference -> { MeetingPart::Sharing.count }, -1 do
      delete sharing_path(@part, households(:home))
    end

    assert_redirected_to household_meeting_part_path(household_id: households(:home), id: @part)
    assert_equal "Stopped sharing with The Head Family.", flash[:notice]
    assert_equal [ households(:parents) ], @part.shared_households
  end

  # From the page, Turbo asks for streams: the label and the button change in place, so the preparation and counsel keep
  # what's typed and not yet saved.
  test "sharing from the page updates its label and button in place" do
    sign_in identities(:head)

    post sharing_path(@part, households(:home)), as: :turbo_stream

    assert_response :success
    assert_turbo_stream(action: :replace, target: "meeting-part-sharing-label") { assert_select ".Label", text: "Shared with The Head Family" }
    assert_turbo_stream(action: :update, target: "meeting-part-sharing") { assert_select "button", text: "Stop sharing" }
    assert_turbo_stream action: :remove, targets: "main .flash:not(.Banner)"
    assert_turbo_stream(action: :prepend, targets: "main .container-xl") { assert_select "template", text: /Shared with The Head Family\./ }
  end

  test "stopping from the page updates its label and button in place" do
    @part.share_with(households(:home))
    sign_in identities(:head)

    delete sharing_path(@part, households(:home)), as: :turbo_stream

    assert_response :success
    assert_turbo_stream(action: :replace, target: "meeting-part-sharing-label") { assert_select ".Label", text: "Private" }
    assert_turbo_stream(action: :update, target: "meeting-part-sharing") { assert_select "button", text: "Share with household" }
  end

  test "anyone else is a 404: a member it's shared with, another member, a non-member, or the owner outside their households" do
    @part.share_with(households(:home))

    [
      [ identities(:spouse), households(:home), -> { delete sharing_path(@part, households(:home)) } ],
      [ identities(:eli), households(:home), -> { post sharing_path(@part, households(:home)) } ],
      [ identities(:outsider), households(:other), -> { post sharing_path(@part, households(:other)) } ],
      [ identities(:head), households(:other), -> { post sharing_path(@part, households(:other)) } ]
    ].each do |identity, _household, request|
      sign_in identity # a 404 doesn't keep the session

      assert_no_difference -> { MeetingPart::Sharing.count } do
        request.call
      end
      assert_response :not_found
    end

    assert_equal [ households(:home) ], @part.reload.shared_households
  end

  private
    def sharing_path(part, household)
      household_meeting_part_sharing_path(household_id: household, meeting_part_id: part)
    end
end
