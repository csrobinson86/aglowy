require "test_helper"

class PersonalNotes::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @note = personal_notes(:head_daniel)
  end

  test "pin: the note page's toggle turns to Pinned in place" do
    sign_in identities(:head)

    assert_difference -> { PersonalNote::Pin.count } do
      post pin_path(@note), as: :turbo_stream
    end

    assert_response :success
    assert @note.reload.pinned?
    assert_turbo_stream action: :replace, target: "pin_personal_note_#{@note.id}" do
      assert_select "form[action=?] button[type=submit][aria-pressed=true]", pin_path(@note), text: "Pinned"
      assert_select "input[name=_method][value=delete]"
    end
    assert_select "turbo-stream[action=refresh]", count: 0
  end

  test "unpin: the toggle turns back to Pin" do
    @note.pin_to_top
    sign_in identities(:head)

    assert_difference -> { PersonalNote::Pin.count }, -1 do
      delete pin_path(@note), as: :turbo_stream
    end

    assert_response :success
    assert_not @note.reload.pinned?
    assert_turbo_stream action: :replace, target: "pin_personal_note_#{@note.id}" do
      assert_select "form[action=?] button[type=submit][aria-pressed=false]", pin_path(@note), text: "Pin"
      assert_select "input[name=_method]", count: 0
    end
  end

  test "pinning a pinned note keeps the one pin" do
    @note.pin_to_top
    sign_in identities(:head)

    assert_no_difference -> { PersonalNote::Pin.count } do
      post pin_path(@note), as: :turbo_stream
    end

    assert_response :success
  end

  # The list knows its own filters, so it refreshes itself; the request id is left off, or Turbo would skip the refresh
  # as an echo of its own request.
  test "unpin from a card on the list refreshes the list" do
    @note.pin_to_top
    sign_in identities(:head)

    delete pin_path(@note), params: { from: "list" }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=refresh]:not([request-id])"
  end

  test "without Turbo, back to where the person was, or the note" do
    sign_in identities(:head)

    post pin_path(@note), headers: { "HTTP_REFERER" => household_personal_notes_url(household_id: @home, color: "orange") }
    assert_redirected_to household_personal_notes_url(household_id: @home, color: "orange")

    delete pin_path(@note)
    assert_redirected_to household_personal_note_path(household_id: @home, id: @note)
    assert_not @note.reload.pinned?
  end

  test "another person's note: 404" do
    note = personal_notes(:spouse_grieving)
    note.pin_to_top

    sign_in identities(:head)
    delete pin_path(note), as: :turbo_stream
    assert_response :not_found
    assert note.reload.pinned?

    note.unpin
    sign_in identities(:head)
    post pin_path(note), as: :turbo_stream
    assert_response :not_found
    assert_not note.reload.pinned?
  end

  test "a non-member: 404" do
    sign_in identities(:outsider)

    post pin_path(@note), as: :turbo_stream

    assert_response :not_found
    assert_not @note.reload.pinned?
  end

  private

  def pin_path(note)
    household_personal_note_pin_path(household_id: @home, personal_note_id: note)
  end
end
