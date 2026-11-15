require "test_helper"

class MeetingNotes::Steps::DrawingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
  end

  test "the drawing page has the prompt, All done, the canvas, seven colours, Undo and Start over" do
    sign_in identities(:eli)

    get edit_drawing_path("field_ministry")

    assert_response :success
    assert_select "body[data-color-mode=dark]"
    assert_select "main h1", "Draw what they shared."
    assert_select "main form[action='#{drawing_path("field_ministry")}'][enctype='multipart/form-data']" do
      assert_select "input[type=hidden][name=_method][value=patch]"
      assert_select "input[type=file][name='drawing[image]'][accept='image/png'][hidden]"
      assert_select "button[type=submit]", "All done"
    end
    assert_select "main canvas[role=img][aria-label='Drawing space. Draw with your finger.']"
    assert_select "main button[type=button][aria-pressed]", 7
    assert_select "main button[type=button][aria-pressed=true][aria-label=Yellow]"
    assert_select "main button[type=button]", text: "Undo"
    assert_select "main button[type=button]", text: "Start over"
    assert_select "[data-meeting-helper--drawing-image-url-value]", count: 0
  end

  test "drawing again loads the saved picture through the drawing route" do
    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    sign_in identities(:eli)

    get edit_drawing_path("talk")

    assert_select "[data-meeting-helper--drawing-image-url-value='#{drawing_path("talk")}']"
    assert_no_match "/rails/active_storage/", response.body
  end

  test "a child saves a drawing" do
    sign_in identities(:eli)

    assert_no_changes -> { households(:home).storage_used } do
      patch drawing_path("talk"), params: { drawing: { image: fixture_file_upload("photo.png", "image/png") } }
    end

    assert_redirected_to step_path("talk")
    drawing = @note.drawings.sole
    assert_equal "talk", drawing.step
    assert_equal file_fixture("photo.png").binread, drawing.image.download
  end

  test "saving again replaces it, so there's still one" do
    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    old_blob = @note.drawings.sole.image.blob
    sign_in identities(:eli)

    perform_enqueued_jobs do
      patch drawing_path("talk"), params: { drawing: { image: fixture_file_upload("photo.png", "image/png") } }
    end

    assert_redirected_to step_path("talk")
    assert_equal 1, @note.drawings.count
    assert_not_equal old_blob, @note.drawings.sole.image.blob
    assert_not ActiveStorage::Blob.exists?(old_blob.id)
  end

  test "a non-PNG shows an error" do
    sign_in identities(:eli)

    patch drawing_path("talk"), params: { drawing: { image: fixture_file_upload("drawing.jpg", "image/png") } }

    assert_response :unprocessable_content
    assert_select "main h1", "Draw who you heard about."
    assert_select "main", text: /Image must be a PNG/
    assert_select "header .meeting-helper__dot--marked", count: 0
    assert_empty @note.drawings
  end

  test "bytes that aren't a picture are refused, whatever type and name they're sent with" do
    sign_in identities(:eli)

    patch drawing_path("talk"), params: { drawing: { image: fixture_file_upload("not-a-picture.png", "image/png") } }

    assert_response :unprocessable_content
    assert_select "main", text: /Image must be a PNG/
    assert_empty @note.drawings
  end

  test "a refused save keeps the saved drawing, and it loads onto the canvas again" do
    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    saved = @note.drawings.sole.image.blob
    sign_in identities(:eli)

    patch drawing_path("talk"), params: { drawing: { image: fixture_file_upload("drawing.jpg", "image/png") } }

    assert_response :unprocessable_content
    assert_select "[data-meeting-helper--drawing-image-url-value='#{drawing_path("talk")}']"
    assert_equal saved, @note.drawings.sole.image.blob
  end

  test "All done without a picture shows an error" do
    sign_in identities(:eli)

    patch drawing_path("talk"), params: { drawing: { image: "" } }

    assert_response :unprocessable_content
    assert_select "main", text: /Image can't be blank/
  end

  test "show redirects for the author" do
    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    sign_in identities(:eli)

    get drawing_path("talk")

    assert_response :redirect
    assert_match %r{\Ahttp://www.example.com/rails/active_storage/disk/}, response.location
    get response.location
    assert_equal file_fixture("photo.png").binread, response.body
  end

  test "show redirects for a household member the note is shared with" do
    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    @note.share_with(households(:home))
    sign_in identities(:head)

    get drawing_path("talk")

    assert_match %r{\Ahttp://www.example.com/rails/active_storage/disk/}, response.location
  end

  test "show still redirects for that member after the helper is turned off" do
    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    @note.share_with(households(:home))
    households(:home).disable_meeting_helper
    sign_in identities(:head)

    get drawing_path("talk")

    assert_match %r{\Ahttp://www.example.com/rails/active_storage/disk/}, response.location
  end

  test "show is 404 for a member it isn't shared with, and for someone outside the household" do
    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    sign_in identities(:head)

    get drawing_path("talk")

    assert_response :not_found

    @note.share_with(households(:home))
    sign_in identities(:outsider)

    get drawing_path("talk")

    assert_response :not_found
  end

  test "show is 404 for a step with no drawing" do
    sign_in identities(:eli)

    get drawing_path("talk")

    assert_response :not_found
  end

  test "another person's note is 404 on edit and update" do
    sign_in identities(:eli)
    other = { household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek), step_id: "talk" }

    get edit_household_meeting_note_step_drawing_path(**other)

    assert_response :not_found

    sign_in identities(:eli) # a 404 doesn't keep the session
    patch household_meeting_note_step_drawing_path(**other), params: { drawing: { image: fixture_file_upload("photo.png", "image/png") } }

    assert_response :not_found
    assert_empty meeting_notes(:head_midweek).drawings
  end

  test "a step from the other kind is 404" do
    sign_in identities(:eli)

    get edit_drawing_path("public_talk")

    assert_response :not_found
  end

  test "a child with the helper off is 404 on edit" do
    households(:home).disable_meeting_helper
    sign_in identities(:eli)

    get edit_drawing_path("talk")

    assert_response :not_found
  end

  private
    def drawing_path(key)
      household_meeting_note_step_drawing_path(household_id: households(:home), meeting_note_id: @note, step_id: key)
    end

    def edit_drawing_path(key)
      edit_household_meeting_note_step_drawing_path(household_id: households(:home), meeting_note_id: @note, step_id: key)
    end

    def step_path(key)
      household_meeting_note_step_path(household_id: households(:home), meeting_note_id: @note, id: key)
    end
end
