require "test_helper"

class FamilyStudy::Draft::NotesHtmlTest < ActiveSupport::TestCase
  OUTLINE = {
    "title" => "Talking to Jehovah as a family",
    "opening" => { "scripture" => "Philippians 4:6, 7", "question" => "What could we tell Jehovah about this week?" },
    "points" => [
      { "heading" => "Jehovah listens to each of us", "scripture" => "Psalm 65:2", "question" => "Why does it matter that Jehovah hears even short prayers?" },
      { "heading" => "We can pray about anything", "question" => "What could we pray about together?" }
    ],
    "children" => "Draw something you want to thank Jehovah for.",
    "closing" => "Choose one thing to thank Jehovah for each day this week."
  }.freeze

  test "the notes contain the references as text" do
    html = Nokogiri::HTML5.fragment(family_study_draft(status: "drafted", outline: OUTLINE).notes_html)

    assert_includes html.text, "Read Philippians 4:6, 7."
    assert_includes html.text, "Ask: What could we tell Jehovah about this week?"
    assert_equal [ "Jehovah listens to each of us", "We can pray about anything" ], html.css("ol > li > p > strong").map(&:text)
    assert_includes html.css("ol > li").first.text, "Read Psalm 65:2."
    assert_includes html.css("ol > li").first.text, "Ask: Why does it matter that Jehovah hears even short prayers?"
    assert_not_includes html.css("ol > li").last.text, "Read"
    assert_includes html.text, "Draw something you want to thank Jehovah for."
    assert_includes html.text, "Choose one thing to thank Jehovah for each day this week."
    assert_empty html.css("a")
  end

  test "the notes escape <script> in a question" do
    outline = OUTLINE.merge("points" => [ { "heading" => "Prayer", "scripture" => "Psalm 65:2", "question" => "<script>alert(1)</script>" } ])
    html = family_study_draft(status: "drafted", outline: outline).notes_html

    assert_includes html, "Ask: &lt;script&gt;alert(1)&lt;/script&gt;"
    assert_empty Nokogiri::HTML5.fragment(html).css("script")
  end

  test "the notes leave out the children's activity when there is none" do
    html = family_study_draft(status: "drafted", outline: OUTLINE.except("children")).notes_html

    assert_not_includes html, "young children"
  end
end
