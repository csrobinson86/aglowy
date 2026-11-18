require "test_helper"

# "Today's thought" on Home, as another member sees a shared brief (docs/design/daily-brief.md, For the children, and
# sharing; Trap 8; frame brief-family.png): the thread, the reading as a link and the children's box, and nothing else.
class DailyBriefs::SharedThoughtComponentTest < ViewComponent::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    travel_to(2.days.ago) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
    @brief = DailyBrief.for(users(:head))
    @result = JSON.parse(JSON.parse(file_fixture("ai/daily_brief.json").read)["content"].filter_map { it["text"] }.join)
  end

  test "the thread, the reading link and the children's box, shared by its owner" do
    daily_brief_writing(@brief, status: "written", result: @result)

    render_inline DailyBriefs::SharedThoughtComponent.new(brief: @brief, household: households(:home))

    assert_selector ".Box-header h2", text: "Today's thought"
    assert_selector ".Box-header .Label", text: "Shared by Hannah Head"
    assert_selector ".shared-thought__thread", text: @result["thread"]
    assert_text "Reading:"
    assert_link "Matthew 16:21-23", href: Bible::Reference.parse("Matthew 16:21-23").jw_url
    assert_selector "h3", text: "For the children"
    assert_text "Ask them"
    assert_text @result.dig("children", "ask")
    assert_text @result.dig("children", "today")
    assert_text "From Hannah Head's daily brief, shared with The Head Family for today. The rest of the brief stays private."
  end

  test "none of the other sections' text is in the output" do
    daily_brief_writing(@brief, status: "written", result: @result)

    render_inline DailyBriefs::SharedThoughtComponent.new(brief: @brief, household: households(:home))

    other_text(@result.except("thread", "reading", "children")).each { assert_no_text it }
    [ @result.dig("reading", "title"), *@result.dig("reading", "look_for").pluck("text") ].each { assert_no_text it }
  end

  test "without the reading or the children's box, only the thread" do
    daily_brief_writing(@brief, status: "written", result: { "thread" => "Only a thread." })

    render_inline DailyBriefs::SharedThoughtComponent.new(brief: @brief, household: households(:home))

    assert_selector ".shared-thought__thread", text: "Only a thread."
    assert_no_text "Reading:"
    assert_no_selector "h3", text: "For the children"
  end

  private
    # Every string in the other sections, long enough not to turn up by chance in the shown ones.
    def other_text(value)
      case value
      when Hash then value.values.flat_map { other_text(it) }
      when Array then value.flat_map { other_text(it) }
      when String then value.length > 12 ? [ value ] : []
      else []
      end
    end
end
