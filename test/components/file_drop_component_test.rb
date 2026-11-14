require "test_helper"

class FileDropComponentTest < ViewComponent::TestCase
  test "renders a labelled file input with the accept list" do
    render_inline(FileDropComponent.new(name: "files[]", direct_upload_url: "/uploads"))

    accept = "application/pdf,image/png,image/jpeg,image/gif,image/webp,image/heic"
    assert_selector "input[type=file][multiple][accept='#{accept}']", visible: :all
    input = page.find("input[type=file]", visible: :all)
    assert_selector "label[for='#{input[:id]}']", text: "Drag your own PDFs or images here, or choose files"
    assert_text "Up to 25 MB each"
    assert_selector "[data-file-drop-url-value='/uploads'][data-file-drop-name-value='files[]']"
  end

  test "keeps files already uploaded, as their names and hidden signed ids" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.png").open, filename: "photo.png")

    render_inline(FileDropComponent.new(name: "files[]", direct_upload_url: "/uploads", blobs: [ blob ]))

    assert_selector "li", text: "photo.png"
    assert_selector "input[type=hidden][name='files[]'][value='#{blob.signed_id}']", visible: :hidden
  end

  test "shows an error, tied to the input" do
    render_inline(FileDropComponent.new(name: "files[]", direct_upload_url: "/uploads", error: "notes.pdf must be a PDF or an image"))

    error = page.find(".FormControl-inlineValidation")
    assert_includes error.text, "notes.pdf must be a PDF or an image"
    assert_includes page.find("input[type=file]", visible: :all)["aria-describedby"], error[:id]
  end

  test "a submit label renders a hidden submit button for when a file is refused" do
    render_inline(FileDropComponent.new(name: "files[]", direct_upload_url: "/uploads", submit_label: "Add files"))

    assert_selector "button[type=submit][hidden]", text: "Add files", visible: :hidden
    assert_selector "[data-file-drop-submit-when-uploaded-value='true']"
  end
end
