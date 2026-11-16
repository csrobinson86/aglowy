require "test_helper"

# A question's answer card in a study's conversation (docs/design/personal-study.md, The study page).
class PersonalStudies::AnswerComponentTest < ViewComponent::TestCase
  SUFFERING = "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/".freeze
  END_OF_SUFFERING = "https://wol.jw.org/en/wol/d/r1/lp-e/1102008083".freeze
  REFUSAL = "That's outside what personal study answers. Ask about the Bible or your spiritual study.".freeze

  setup do
    @household = households(:home)
  end

  test "asking: progress lines only, in a live region, with Stop" do
    question = personal_study_question

    render_inline(PersonalStudies::AnswerComponent.new(question:, household: @household))

    assert_selector "turbo-cable-stream-source", visible: :all
    assert_selector "ul[id='progress_personal_study_question_#{question.id}'][aria-live=polite] li", count: 3
    assert_selector "ul[aria-live] strong", text: "Searching jw.org and wol.jw.org…"
    assert_button "Stop"
    assert_no_text "From jw.org and wol.jw.org"
    assert_no_text "Pages used"
  end

  test "answered: the source line, escaped paragraphs, the pages used and the check" do
    render_answered

    assert_text "From jw.org and wol.jw.org"
    assert_selector "p", text: "Jehovah never causes suffering (James 1:13)."
    assert_selector "h3", text: "Pages used"
    assert_link "Why Does God Allow Suffering?", href: SUFFERING
    assert_text "Check each point against its page."
    assert_no_selector ".color-bg-subtle", text: "I couldn't find"
    assert_no_button "Stop"
    assert_no_selector "turbo-cable-stream-source", visible: :all
  end

  test "a <script> in a paragraph renders as text" do
    render_answered(paragraphs: [ "<script>alert('hi')</script> Read Romans 5:12." ])

    assert_no_selector "script", visible: :all
    assert_selector "p", text: "<script>alert('hi')</script> Read Romans 5:12."
    assert_link "Romans 5:12"
  end

  test "references become scripture links" do
    render_answered(paragraphs: [ "Sin spread to everyone (Romans 5:12), and he will end suffering (Revelation 21:3, 4)." ])

    assert_link "Romans 5:12", href: "https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=45005012"
    assert_link "Revelation 21:3, 4", href: /bible=66021003-66021004/
    assert_selector "a.scripture-link[target=_blank][rel=noopener]", count: 2
  end

  test "only title, host and link for sources" do
    render_answered(sources: [ { "url" => SUFFERING, "title" => "Why Does God Allow Suffering?", "cited_text" => "An excerpt never shown." },
                               { "url" => END_OF_SUFFERING, "title" => "The End of Suffering" } ])

    pages = "ul[aria-label='Pages used']"
    assert_selector "#{pages} li", count: 2
    assert_selector "#{pages} li", text: /\A\s*Why Does God Allow Suffering\? · jw\.org\s*\z/
    assert_selector "#{pages} li", text: /\A\s*The End of Suffering · wol\.jw\.org\s*\z/
    assert_selector "#{pages} a[href='#{SUFFERING}'][target=_blank][rel=noopener]", text: "Why Does God Allow Suffering?"
    assert_selector "#{pages} a[href='#{END_OF_SUFFERING}'][target=_blank][rel=noopener]", text: "The End of Suffering"
    assert_no_text "An excerpt never shown."
  end

  test "Keep digging: each next question is a chip that fills the ask box" do
    render_answered(next_questions: [ "How does the ransom fit in?", "What did Job learn?" ])

    assert_selector "h3", text: "Keep digging"
    assert_button "How does the ransom fit in?", type: "button"
    assert_selector "button[data-action='study-ask#fill'][data-study-ask-text-param='What did Job learn?']", text: "What did Job learn?"
  end

  test "not found: the note in a muted box first" do
    render_answered(not_found: true, not_found_note: "I couldn't find jw.org or wol.jw.org giving a length of time, so I won't guess one.",
                    paragraphs: [ "Jesus said no one knows the day or hour (Matthew 24:36)." ])

    assert_selector ".color-bg-subtle:first-child", text: "I couldn't find jw.org or wol.jw.org giving a length of time, so I won't guess one."
    assert_selector ".color-bg-subtle + p", text: "Jesus said no one knows the day or hour"
    assert_link "Matthew 24:36"
  end

  test "not found with no paragraphs or pages shows the note alone" do
    render_answered(not_found: true, not_found_note: "I couldn't find jw.org or wol.jw.org pages that answer this.", paragraphs: [], sources: [], next_questions: [])

    assert_text "I couldn't find jw.org or wol.jw.org pages that answer this."
    assert_no_text "Pages used"
    assert_no_text "Keep digging"
  end

  test "off topic and flagged: the refusal, and nothing else" do
    %w[ off_topic flagged ].each do |status|
      render_inline(PersonalStudies::AnswerComponent.new(question: personal_study_question(status:), household: @household))

      assert_text REFUSAL
      assert_no_text "From jw.org and wol.jw.org"
      assert_no_button "Stop"
    end
  end

  test "failed: try again, with the question kept for the box" do
    question = personal_study_question(status: "failed")

    render_inline(PersonalStudies::AnswerComponent.new(question:, household: @household))

    assert_text "Couldn't answer right now. Try again."
    assert_selector "button[data-action='study-ask#fill'][data-study-ask-text-param='#{question.prompt}']", text: "Ask it again"
  end

  test "stopped" do
    render_inline(PersonalStudies::AnswerComponent.new(question: personal_study_question(status: "stopped"), household: @household))

    assert_text "You stopped this answer."
    assert_no_button "Stop"
    assert_no_text "From jw.org and wol.jw.org"
  end

  private
    def render_answered(sources: [ { "url" => SUFFERING, "title" => "Why Does God Allow Suffering?" } ], **answer)
      answer = { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ],
                 "next_questions" => [] }.merge(answer.stringify_keys)

      render_inline(PersonalStudies::AnswerComponent.new(question: personal_study_question(status: "answered", answer:, sources:), household: @household))
    end
end
