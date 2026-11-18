require "test_helper"

# The person's own daily brief at the top of Home (docs/design/daily-brief.md, On Home; frame brief-home.png): the
# thread, the reading, the quality and the faith example, and Open today's brief. Tuesday 17 November 2026, from the
# husband-and-father starter, whose Tuesday is Matthew – John, Patience, Mildness and Abraham, Moses.
class DailyBriefs::HomeCardComponentTest < ViewComponent::TestCase
  include ActiveSupport::Testing::TimeHelpers

  HREF = "/home/daily_brief".freeze

  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    @plan = travel_to(2.days.ago) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
  end

  test "with a written writing: the thread and the AI's reading, quality and examples" do
    brief = DailyBrief.for(users(:head))
    body = JSON.parse(file_fixture("ai/daily_brief.json").read)
    daily_brief_writing(brief, status: "written", result: JSON.parse(body["content"].filter_map { it["text"] }.join))

    render_inline DailyBriefs::HomeCardComponent.new(brief:, href: HREF)

    assert_selector ".Box-header h2", text: "Your daily brief"
    assert_selector ".Box-header", text: "Only you see this"
    assert_selector ".daily-brief-home-card__thread", text: "Patience is letting Jehovah's timing be Jehovah's timing"
    assert_fact "Reading", "Matthew 16:21-23"
    assert_fact "Quality", "Patience"
    assert_fact "Imitate their faith", "Abraham and Moses"
    assert_link "Open today's brief", href: HREF
    assert_text "About 10 minutes. This evening it has four questions to end the day."
  end

  test "with the parts from the plan only: what the plan gives for today and no thread" do
    brief = DailyBrief.for(users(:head))

    render_inline DailyBriefs::HomeCardComponent.new(brief:, href: HREF)

    assert_selector ".Box-header h2", text: "Your daily brief"
    assert_no_selector ".daily-brief-home-card__thread"
    assert_fact "Reading", "Matthew – John"
    assert_fact "Quality", "Patience, Mildness"
    assert_fact "Imitate their faith", "Abraham, Moses"
    assert_link "Open today's brief", href: HREF
    assert_no_text "About 10 minutes"
  end

  test "a writing that isn't written yet shows the parts from the plan" do
    brief = DailyBrief.for(users(:head))
    daily_brief_writing(brief)

    render_inline DailyBriefs::HomeCardComponent.new(brief:, href: HREF)

    assert_no_selector ".daily-brief-home-card__thread"
    assert_fact "Reading", "Matthew – John"
  end

  test "a section that's off leaves its fact out" do
    @plan.update!(sections: %w[ daily_text ])
    brief = DailyBrief.for(users(:head))

    render_inline DailyBriefs::HomeCardComponent.new(brief:, href: HREF)

    assert_no_selector "dt", text: "Reading"
    assert_no_selector "dt", text: "Imitate their faith"
    assert_fact "Quality", "Patience, Mildness"
  end

  test "a plan with no quality and an empty day has no facts, and still opens the brief" do
    @plan.focus_areas.quality.delete_all
    @plan.days.update_all(reading: nil, examples: nil, topics: {})
    brief = DailyBrief.for(users(:head))

    render_inline DailyBriefs::HomeCardComponent.new(brief:, href: HREF)

    assert_no_selector "dl"
    assert_link "Open today's brief", href: HREF
  end

  private
    def assert_fact(label, value)
      assert_selector(".daily-brief-home-card__fact") { it.has_selector?("dt", exact_text: label) && it.has_selector?("dd", exact_text: value) }
    end
end
