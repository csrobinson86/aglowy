require "test_helper"

class Bible::LinkerTest < ActiveSupport::TestCase
  test "matt 24:14 becomes a Matthew 24:14 attachment" do
    linked = link("<p>Read matt 24:14 tonight</p>")

    assert_equal [ Bible::Reference.find("40:24:14") ], linked.attachables
    assert_equal "Read Matthew 24:14 tonight", linked.to_plain_text
  end

  test "Ps 37:8-9. becomes Psalm 37:8, 9, with the full stop kept outside the link" do
    linked = link("<p>Let go of anger. Ps 37:8-9.</p>")

    assert_equal [ Bible::Reference.find("19:37:8-9") ], linked.attachables
    assert_match %r{</action-text-attachment>\.</p>}, linked.to_html
  end

  test "two references in one sentence become two links" do
    linked = link("<p>Compare matt 24:14 with 1 cor 13:4-7 and Song of Solomon 8:6.</p>")

    assert_equal %w[ 40:24:14 46:13:4-7 22:8:6 ].map { Bible::Reference.find(it) }, linked.attachables
    assert_equal "Compare Matthew 24:14 with 1 Corinthians 13:4-7 and Song of Solomon 8:6.", linked.to_plain_text
  end

  test "a non-breaking space, as editors often type, counts as a space" do
    linked = link("<p>Read matt&nbsp;24:14&nbsp;tonight</p>")

    assert_equal [ Bible::Reference.find("40:24:14") ], linked.attachables
  end

  test "references in a list each become a link, and a comma that joins no verses stays text" do
    linked = link("<p>Matt 24:14, 2 Tim 3:1 and Ps 37:8, 10</p>")

    assert_equal %w[ 40:24:14 55:3:1 19:37:8 ].map { Bible::Reference.find(it) }, linked.attachables
    assert_equal "Matthew 24:14, 2 Timothy 3:1 and Psalm 37:8, 10", linked.to_plain_text
  end

  test "text that only looks a bit like a reference is left as text" do
    [ "Job 5", "Acts of kindness", "John 3", "1 John", "Psalm 151:1", "page 24:14", "Matt 24:14a", "rematt 24:14", "Gen 1:1-2:3", "Ps 37:8-100" ].each do |text|
      html = "<p>#{text}</p>"

      assert_empty link(html).attachables, text
      assert_equal text, link(html).to_plain_text
    end
  end

  test "a numbered book whose verses don't exist stays text, not a link to the book without its number" do
    linked = link("<p>Read 1 John 3:36 and 2 John 1:20</p>")

    assert_empty linked.attachables
    assert_equal "Read 1 John 3:36 and 2 John 1:20", linked.to_plain_text
  end

  test "text inside an existing link or code is unchanged" do
    html = %(<p><a href="https://example.com">matt 24:14</a></p><p><code>ps 37:8</code></p><pre>John 3:16</pre>)

    linked = link(html)

    assert_empty linked.attachables
    assert_equal ActionText::Content.new(html).to_html, linked.to_html
  end

  test "an existing scripture attachment is unchanged, not doubled" do
    html = "<p>Already linked #{scripture_attachment("19:37:8-9")} and typed matt 24:14</p>"

    linked = link(html)

    assert_equal %w[ 19:37:8-9 40:24:14 ].map { Bible::Reference.find(it) }, linked.attachables
    assert_equal linked.to_html, link(linked.to_html).to_html, "linking again changes nothing"
  end

  private
    def link(html)
      Bible::Linker.new(ActionText::Content.new(html)).link
    end
end
