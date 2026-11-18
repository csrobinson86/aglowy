require "test_helper"

class DailyBriefs::PlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    users(:head).update!(time_zone: "Central Time (US & Canada)")
  end

  test "show with no plan redirects to new" do
    sign_in identities(:head)

    get household_daily_brief_plan_path(household_id: @home)

    assert_redirected_to new_household_daily_brief_plan_path(household_id: @home)
  end

  test "new with a plan redirects to show" do
    DailyBrief::Plan.start(users(:head), starter: "basics")
    sign_in identities(:head)

    get new_household_daily_brief_plan_path(household_id: @home)

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
  end

  test "new offers the four starters as a radio group, with the AI notice and Start my daily brief" do
    sign_in identities(:spouse)

    get new_household_daily_brief_plan_path(household_id: @home)

    assert_response :success
    assert_select "title", "Daily brief · The Head Family · Aglowy"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Daily brief"
    assert_select "h1", "Start your day with a daily brief"
    assert_select "form[action=?]", household_daily_brief_plan_path(household_id: @home) do
      assert_select "fieldset legend", "Start from a plan"
      assert_select "input[type=radio][name='daily_brief_plan[starter]']", count: 4
      assert_select "label", "A husband and father"
      assert_select "*", text: "As a husband · As a father · Reaching out · Qualities to focus on · Growing appreciation for Jehovah"
      assert_select "label", "The basics"
      assert_select "*", text: "Daily text, a Bible reading, a quality and a faith example. Add focus areas later."
      assert_select "button[type=submit]", "Start my daily brief"
    end
    assert_select "main", text: /Written by AI, from jw.org and wol.jw.org/
    assert_select "main", text: /Your first brief is ready tomorrow morning./
  end

  test "create with each starter makes the plan and opens it" do
    { head: "husband_and_father", spouse: "wife_and_mother" }.each do |person, starter|
      sign_in identities(person)

      assert_difference -> { DailyBrief::Plan.count } do
        post household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { starter: } }
      end

      assert_redirected_to household_daily_brief_plan_path(household_id: @home)
      assert_equal DailyBrief::Starter.find(starter).focus_areas.map(&:name), users(person).reload.daily_brief_plan.focus_areas.map(&:name)
    end

    %w[ on_my_own basics ].each do |starter|
      sign_in identities(:grandparent)
      users(:grandparent).daily_brief_plan&.destroy!

      post household_daily_brief_plan_path(household_id: households(:parents)), params: { daily_brief_plan: { starter: } }

      assert_redirected_to household_daily_brief_plan_path(household_id: households(:parents))
      assert_equal DailyBrief::Starter.find(starter).focus_areas.map(&:name), users(:grandparent).reload.daily_brief_plan.focus_areas.map(&:name)
    end
  end

  test "a missing starter re-renders Start with :unprocessable_content" do
    sign_in identities(:head)

    assert_no_difference -> { DailyBrief::Plan.count } do
      post household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { starter: "" } }
    end

    assert_response :unprocessable_content
    assert_select "h1", "Start your day with a daily brief"
    assert_select "main", text: /Choose a plan to start from/
  end

  test "a starter sent outside daily_brief_plan[] is a 400 and makes no plan" do
    sign_in identities(:head)

    assert_no_difference -> { DailyBrief::Plan.count } do
      post household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: "basics" }
    end

    assert_response :bad_request
  end

  test "create with a plan already started keeps it and opens it" do
    plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    sign_in identities(:head)

    assert_no_difference -> { DailyBrief::FocusArea.count } do
      post household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { starter: "basics" } }
    end

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_equal plan, users(:head).reload.daily_brief_plan
  end

  test "show is the plan: focus areas, the week with today marked, the sections, ready-by in the person's zone and what's sent" do
    DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    sign_in identities(:head)

    travel_to Time.find_zone("Central Time (US & Canada)").local(2026, 11, 17, 9) do # a Tuesday
      get household_daily_brief_plan_path(household_id: @home)
    end

    assert_response :success
    assert_select "title", "Your plan · The Head Family · Aglowy"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Daily brief"
    assert_select "h1", "Your plan"
    assert_select "section[aria-labelledby=focus-areas] li", count: 5 do |rows|
      assert_select rows.first, "h3", "As a husband"
      assert_select rows.first, "*", text: "One way to show love, honesty and loyalty to my wife today."
      assert_select rows[2], "a.scripture-link[href^='https://www.jw.org/finder']", text: "1 Timothy 3:8-13"
    end
    assert_select "section[aria-labelledby=week] table" do
      assert_equal [ "Day", "Reading", "Qualities", "As a husband", "As a father", "Reaching out", "Faith examples" ], css_select("thead th").map { it.text.strip }
      assert_equal %w[ Mon Tue Wed Thu Fri Sat Sun ], css_select("tbody tr th").map { it.text.split.first }
      assert_select "tbody tr", count: 7
      assert_select "tbody tr:nth-child(2)" do
        assert_select "th", text: /Tue\s+Today/
        assert_select "td", text: "Matthew – John"
        assert_select "td", text: "Patience, Mildness"
        assert_select "td", text: "The brief chooses"
        assert_select "td", text: "Patient teaching of my children"
        assert_select "td", text: "Serious (v. 8)"
      end
      assert_select "tbody", text: /Today/, count: 1
    end
    assert_select "section[aria-labelledby=focus-areas]" do
      assert_select "a[href=?][data-turbo-frame=daily_brief_focus_area_dialog]", new_household_daily_brief_plan_focus_area_path(household_id: @home),
                    text: "Add a focus area"
      assert_select "a[aria-label='Edit As a husband'][data-turbo-frame=daily_brief_focus_area_dialog]", text: "Edit"
      assert_select "a[aria-label^='Edit ']", count: 5
      assert_equal [ "As a wife", "As a mother", "In the ministry", "In the congregation", "At work", "Guard your heart" ],
                   css_select("a[href*='from=']").map { it.text.strip }
    end
    assert_select "turbo-frame#daily_brief_focus_area_dialog"
    assert_select "form[action=?]", household_daily_brief_plan_path(household_id: @home) do
      assert_select "input[name=_method][value=patch]"
      assert_select "section[aria-labelledby=sections] input[type=checkbox][name='daily_brief_plan[sections][]']:checked", count: 5
      assert_select "section[aria-labelledby=sections] label", text: "Evening questions"
      assert_select "select[name='daily_brief_plan[ready_at_minutes]']" do
        assert_equal [ "4:00 AM", "4:30 AM", "5:00 AM", "5:30 AM", "6:00 AM", "6:30 AM", "7:00 AM", "7:30 AM", "8:00 AM" ],
                     css_select("option").map(&:text)
        assert_select "option[selected][value='300']", "5:00 AM"
      end
      assert_select "button[type=submit]", "Save plan"
    end
    assert_select "label", "Ready by"
    assert_select "main", text: /Central Time \(US & Canada\)/
    assert_select "section[aria-labelledby=whats-sent]", text: /Aglowy adds nothing else/
  end

  test "update saves the sections and ready-by, and goes back to the plan" do
    plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    sign_in identities(:head)

    patch household_daily_brief_plan_path(household_id: @home),
          params: { daily_brief_plan: { sections: [ "", "daily_text", "reading", "faith_example", "evening" ], ready_at_minutes: "360" } }

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_equal "Plan saved. Your next brief follows it.", flash[:notice]
    plan.reload
    assert_equal %w[ daily_text reading faith_example evening ], plan.sections
    assert_equal 360, plan.ready_at_minutes

    follow_redirect!
    assert_select "input[type=checkbox][value=children]:not(:checked)"
    assert_select "option[selected]", "6:00 AM"
  end

  test "update with every section unticked leaves none" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    sign_in identities(:head)

    patch household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { sections: [ "" ], ready_at_minutes: "300" } }

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_empty plan.reload.sections
  end

  test "an unknown section is refused with :unprocessable_content" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    sign_in identities(:head)

    patch household_daily_brief_plan_path(household_id: @home),
          params: { daily_brief_plan: { sections: [ "", "daily_text", "prayer" ], ready_at_minutes: "300" } }

    assert_response :unprocessable_content
    assert_select "h1", "Your plan"
    assert_select "main", text: /can only be daily_text, reading, faith_example, children and evening/
    assert_equal DailyBrief::Plan::SECTIONS, plan.reload.sections
  end

  test "a time off the half hour is refused with :unprocessable_content" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    sign_in identities(:head)

    [ "315", "510" ].each do |minutes|
      patch household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { sections: [ "" ], ready_at_minutes: minutes } }

      assert_response :unprocessable_content
      assert_select "main", text: /Choose a time from 4:00 to 8:00 AM/
    end
    assert_equal 300, plan.reload.ready_at_minutes
    assert_equal DailyBrief::Plan::SECTIONS, plan.sections
  end

  test "update with no plan is a 404" do
    sign_in identities(:head)

    patch household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { sections: [ "" ], ready_at_minutes: "300" } }

    assert_response :not_found
  end

  test "a child is refused" do
    sign_in identities(:eli)

    get new_household_daily_brief_plan_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]

    assert_no_difference -> { DailyBrief::Plan.count } do
      post household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { starter: "basics" } }
    end
    assert_redirected_to household_root_path(household_id: @home)

    get household_daily_brief_plan_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)

    patch household_daily_brief_plan_path(household_id: @home), params: { daily_brief_plan: { sections: [ "" ], ready_at_minutes: "300" } }
    assert_redirected_to household_root_path(household_id: @home)
  end

  test "another household's URL is a 404" do
    sign_in identities(:outsider)

    get new_household_daily_brief_plan_path(household_id: @home)

    assert_response :not_found
  end
end
