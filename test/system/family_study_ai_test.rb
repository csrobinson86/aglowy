require "application_system_test_case"

# The AI panel beside the Schedule form (docs/design/family-studies.md, AI helper). The test queue adapter only
# enqueues the draft's job, so nothing here calls an AI provider.
class FamilyStudyAiTest < ApplicationSystemTestCase
  test "a head turns on AI drafts, describes a study and sees Drafting with AI" do
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))

    within("turbo-frame#ai_panel") do
      assert_selector "h2", text: "Plan it with AI"
      click_on "Draft with AI"
      assert_selector "h2", text: "Before you use AI"
    end
    assert_accessible
    capture_screens("ai-terms", scroll_to: "[data-ai-panel-target=opened]")

    within("turbo-frame#ai_panel") do
      check "I understand how AI drafts work"
      click_on "Turn on AI drafts"
      assert_field "What should the study be about?"
      click_on "Something we're facing"
      assert_field "What should the study be about?", with: /\ASomething our family is facing: /
      fill_in "What should the study be about?", with: "Trusting Jehovah when we feel anxious. Simple enough for younger children to join in."
      check "Keep it easy for young children to follow"
      assert_text "10 of 10 drafts left today"
    end
    assert_accessible
    capture_screens("ai-describe", scroll_to: "[data-ai-panel-target=opened]")

    within("turbo-frame#ai_panel") { click_on "Draft outline" }

    assert_selector "turbo-frame#ai_panel", text: "Drafting with AI"
    assert_equal "Trusting Jehovah when we feel anxious. Simple enough for younger children to join in.", households(:home).family_study_drafts.sole.prompt
    assert_predicate users(:head), :accepted_ai_terms?
  end

  test "Not now and Cancel go back to the start" do
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))

    within("turbo-frame#ai_panel") do
      click_on "Draft with AI"
      click_on "Not now"
      assert_button "Draft with AI"
      assert_no_selector "h2", text: "Before you use AI"
    end
  end

  test "with 10 used: Limit reached, and the form still schedules a study" do
    users(:head).accept_ai_terms(understood: "1")
    10.times { family_study_draft(household: households(:home)) }
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))

    within("turbo-frame#ai_panel") do
      click_on "Draft with AI"
      assert_text "You've used today's 10 drafts"
      assert_button "Draft outline", disabled: true
    end
    assert_accessible
    capture_screens("ai-limit", scroll_to: "[data-ai-panel-target=opened]")

    date = 7.days.from_now.to_date
    fill_in "What will you study?", with: "Proverbs 3"
    fill_in "Date", with: date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    click_on "Schedule study"

    assert_text "Your family study is scheduled."
    assert_selector ".Box-row", text: "Proverbs 3"
  end

  test "on a phone the panel stacks under the form" do
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))
    emulate_viewport(390, 844, phone: true)

    assert_selector "turbo-frame#ai_panel h2", text: "Plan it with AI"
    assert_operator evaluate_script("document.querySelector('[data-ai-panel-target=start]').getBoundingClientRect().top"), :>,
      evaluate_script("document.querySelector('#schedule-links').getBoundingClientRect().top")
  ensure
    cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "a child sees no panel" do
    sign_in identities(:eli)
    visit new_household_family_study_url(household_id: households(:home))

    assert_text "You can't do that in this household."
    assert_no_selector "turbo-frame#ai_panel"
    assert_no_text "Plan it with AI"
  end
end
