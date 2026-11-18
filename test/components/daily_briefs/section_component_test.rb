require "test_helper"

# One bordered section of the brief: a kicker, an h2, then a link and rows (docs/design/daily-brief.md, The brief; frame
# brief-base.png).
class DailyBriefs::SectionComponentTest < ViewComponent::TestCase
  Row = DailyBriefs::SectionComponent::Row

  test "a section with rows" do
    render_inline DailyBriefs::SectionComponent.new(kicker: "Your focus today", title: "From your plan", rows: [
      Row.new(label: "As a husband", text: "Love my wife as my own body."),
      Row.new(label: "As a father", text: "One way to teach my children.")
    ])

    assert_selector "section.daily-brief-section[aria-labelledby]" do
      assert_selector ".daily-brief-section__kicker", text: "Your focus today"
      assert_selector "h2", text: "From your plan"
      assert_selector "dt", text: "As a husband"
      assert_selector "dd", text: "Love my wife as my own body."
      assert_selector "dt", text: "As a father"
    end
    assert_selector "section[aria-labelledby='#{page.find("h2")[:id]}']"
  end

  test "a section with a link" do
    render_inline DailyBriefs::SectionComponent.new(kicker: "Daily text", title: "Tuesday, November 17",
      link: DailyBriefs::SectionComponent::Link.new(text: "Open today's text on wol.jw.org", href: "https://wol.jw.org/en/wol/dt/r1/lp-e/2026/11/17",
                                                    note: "the text and its comment are read there"))

    assert_link "Open today's text on wol.jw.org", href: "https://wol.jw.org/en/wol/dt/r1/lp-e/2026/11/17"
    assert_selector "a[target=_blank][rel~=noopener]"
    assert_text "the text and its comment are read there"
    assert_no_selector "dl"
  end

  test "a section with a reference" do
    reference = Bible::Reference.parse("Galatians 5:22, 23")

    render_inline DailyBriefs::SectionComponent.new(kicker: "Qualities to focus on", title: "Patience, Mildness", rows: [
      Row.new(label: "From your week", text: "Tuesday's qualities.", references: [ reference, Bible::Reference.parse("Colossians 3:12") ])
    ])

    assert_link "Galatians 5:22, 23", href: reference.jw_url
    assert_link "Colossians 3:12"
    assert_selector "dd", text: /Tuesday's qualities\.\s+Galatians 5:22, 23/
  end

  test "a section with nothing to show renders nothing" do
    render_inline DailyBriefs::SectionComponent.new(kicker: "Imitate their faith", title: nil, rows: [
      Row.new(label: "From your week", text: "Tuesday's examples.")
    ])

    assert_no_selector "section"
  end

  test "a row the AI left empty is dropped, unless it carries a linked goal" do
    render_inline DailyBriefs::SectionComponent.new(kicker: "Patience", title: "Patience", rows: [
      Row.new(label: "How Jesus showed it", text: nil),
      Row.new(label: "One way today", text: nil, note: "Your goal: Be more patient")
    ])

    assert_no_selector "dt", text: "How Jesus showed it"
    assert_selector "dt", text: "One way today"
    assert_selector "dd", text: "Your goal: Be more patient"
  end

  test "what the plan says is escaped" do
    render_inline DailyBriefs::SectionComponent.new(kicker: "<b>As a husband</b>", title: "<script>x</script>", rows: [
      Row.new(label: "<i>Today</i>", text: "<img src=x>")
    ])

    assert_no_selector "b, i, img, script"
    assert_selector "h2", text: "<script>x</script>"
  end
end
