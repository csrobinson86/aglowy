require "application_system_test_case"

class TickGoalStepsTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "an adult ticks a step and the progress updates" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))
    assert_text "3 of 7 steps done"
    page.execute_script("window.stillTheSamePage = true")

    check "Mark Read Luke together done"
    assert_text "4 of 7 steps done"
    within("##{dom_id(goal_steps(:read_luke))}") { assert_text "Everyone · Done together · Nov 14" }
    assert_text "Sam Spouse · 3 of 5"

    within("##{dom_id(goal_steps(:parables))}") do
      within("[role=group][aria-label='Each person ticks their own part']") do
        assert_selector "button[aria-pressed=true]", text: "Eli Child done"
        click_on "Sofia Child"
        assert_selector "button[aria-pressed=true]", text: "Sofia Child done"
        assert_selector "button:focus", text: "Sofia Child done"
      end
      assert_text "Done by Eli Child and Sofia Child"
    end
    assert_text "5 of 7 steps done"
    assert_no_text "Every step is done. Mark the goal complete?"

    uncheck "Mark Read Luke together done"
    assert_text "4 of 7 steps done"
    within("##{dom_id(goal_steps(:read_luke))}") { assert_text "Everyone · Due Feb 15" }

    assert_accessible
    assert page.evaluate_script("window.stillTheSamePage"), "expected Turbo to update the page in place"
  end

  test "a tick that never reaches the server puts the checkbox back" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))
    assert_text "3 of 7 steps done"
    page.execute_script(<<~JS)
      const fetch = window.fetch
      window.fetch = () => { window.fetch = fetch; return Promise.reject(new TypeError("offline")) }
    JS

    check "Mark Read Luke together done"

    assert_no_checked_field "Mark Read Luke together done"
    assert_text "3 of 7 steps done"
    check "Mark Read Luke together done"
    assert_text "4 of 7 steps done"
  end

  test "a second change while a tick is on its way still lets a failure put the checkbox back" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))
    assert_text "3 of 7 steps done"
    page.execute_script(<<~JS)
      window.realFetch = window.fetch
      window.fetch = (url, { signal }) => new Promise((resolve, reject) => {
        signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")))
        setTimeout(() => reject(new TypeError("offline")), 1000)
      })
    JS

    check "Mark Read Luke together done"
    uncheck "Mark Read Luke together done"

    assert_no_checked_field "Mark Read Luke together done"
    assert_text "3 of 7 steps done"
    page.execute_script("window.fetch = window.realFetch")
    check "Mark Read Luke together done"
    assert_text "4 of 7 steps done"
  end

  test "the last tick shows the Banner to an adult" do
    %i[ read_luke read_john ].each { goal_steps(it).tick(for: nil, by: users(:spouse)) }
    goal_steps(:parables).tick(for: users(:sofia), by: users(:spouse))
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))
    assert_text "6 of 7 steps done"

    check "Mark Share what each of us learned done"

    assert_text "7 of 7 steps done"
    assert_selector ".Banner", text: "Every step is done. Mark the goal complete?"
    assert_accessible
  end

  test "Eli ticks his part of the parables step and can't tick Sofia's" do
    goal_step_completions(:parables_eli).destroy!
    sign_in Identity.create!(user: users(:eli), email: "eli@example.com", password: "password123", confirmed_at: Time.current)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))

    assert_text "You can tick the steps that are yours"
    assert_selector "##{dom_id(goal_steps(:read_luke))} input[type=checkbox][disabled]"
    assert_selector "##{dom_id(goal_steps(:draw_map))} input[type=checkbox]:not([disabled])"
    assert_selector "##{dom_id(goal_steps(:parables))} .goal-step--yours"
    assert_no_selector "##{dom_id(goal_steps(:read_luke))} .goal-step--yours"

    within("##{dom_id(goal_steps(:parables))} [role=group]") do
      assert_selector "button[disabled][aria-pressed=false]", text: "Sofia Child"
      click_on "Eli Child"
      assert_selector "button[aria-pressed=true]", text: "Eli Child done"
    end
    within("##{dom_id(goal_steps(:parables))}") { assert_text "Eli Child done · waiting on Sofia Child" }
    assert_text "Eli Child · 4 of 6"
    assert_no_text "Every step is done. Mark the goal complete?"

    assert_accessible
    capture_screens("goal-child", scroll_to: "##{dom_id(goal_steps(:parables))}")
  end

  private
    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
    end
end
