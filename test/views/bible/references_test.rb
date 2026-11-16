require "test_helper"

class Bible::ReferencesTest < ActionView::TestCase
  setup { @psalm = Bible::Reference.find("19:37:8-9") }

  test "the reference partial links to the passage on jw.org in a new tab, with a hidden icon" do
    render partial: "bible/references/reference", locals: { reference: @psalm }

    assert_dom "a.scripture-link[href=?][target=_blank][rel=noopener]", @psalm.jw_url, text: "Psalm 37:8, 9" do
      assert_dom "svg.octicon-link-external[aria-hidden=true]"
    end
  end

  # Only the link and its text: Action Text's sanitizer drops target, rel and the icon from a saved note, which the
  # story that renders saved notes has to settle.
  test "a note renders its scripture attachment as the link" do
    content = ActionText::Content.new(%(<action-text-attachment sgid="#{@psalm.attachable_sgid}"></action-text-attachment>))

    render inline: "<%= content %>", locals: { content: }

    assert_dom "action-text-attachment a.scripture-link", text: "Psalm 37:8, 9"
  end

  test "the editor partial shows the same text styled as a link, but not clickable" do
    render partial: "bible/references/editor", locals: { reference: @psalm }

    assert_dom "span.scripture-link", text: "Psalm 37:8, 9" do
      assert_dom "svg.octicon-link-external[aria-hidden=true]"
    end
    assert_dom "a", count: 0
  end
end
