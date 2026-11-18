require "test_helper"

class DailyBriefs::Plans::DaysControllerTest < ActionDispatch::IntegrationTest
  CAPTION = "Sent to the AI as you type it. Leave out names."

  setup do
    @home = households(:home)
    @plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    @areas = @plan.focus_areas.index_by(&:name)
    @tuesday = @plan.days.find_by!(wday: 2)
    sign_in identities(:head)
  end

  test "edit is the day's dialog: Reading, a box per focus area, and Faith examples, each filled in" do
    get edit_household_daily_brief_plan_day_path(household_id: @home, wday: 2)

    assert_response :success
    assert_select "turbo-frame#daily_brief_day_dialog dialog[open]" do
      assert_select "h1", "Edit Tuesday"
      assert_select "form[action=?]", household_daily_brief_plan_day_path(household_id: @home, wday: 2) do
        assert_select "input[name='daily_brief_day[reading]'][value=?]", "Matthew – John"
        assert_select "input[name='daily_brief_day[topics][#{@areas["Qualities to focus on"].id}]'][value=?]", "Patience, Mildness"
        assert_select "input[name='daily_brief_day[topics][#{@areas["As a father"].id}]'][value=?]", "Patient teaching of my children"
        assert_select "input[name='daily_brief_day[topics][#{@areas["As a husband"].id}]']:not([value])"
        assert_select "input[name='daily_brief_day[topics][#{@areas["Growing appreciation for Jehovah"].id}]']"
        assert_select "input[name='daily_brief_day[examples]'][value=?]", "Abraham, Moses"
        assert_select "label", text: "Qualities"
        assert_select "label", text: "Reaching out"
        assert_select "label", text: "Growing appreciation for Jehovah"
        assert_select "button[type=submit]", "Save Tuesday"
      end
    end
  end

  test "every box carries the Sent to the AI caption" do
    get edit_household_daily_brief_plan_day_path(household_id: @home, wday: 2)

    boxes = css_select("dialog input[type=text]")
    assert_equal 7, boxes.size
    boxes.each do |box|
      caption_id = box["aria-describedby"].split.find { it.start_with?("caption-") }
      assert_select "##{caption_id}", text: CAPTION
    end
  end

  test "update saves the day, closes the dialog and redraws the week with focus on the day's Edit" do
    patch household_daily_brief_plan_day_path(household_id: @home, wday: 2), as: :turbo_stream,
          params: { daily_brief_day: { reading: "Luke", examples: "Mary", topics: { @areas["As a husband"].id => "Listen first" } } }

    assert_response :success
    assert_select "turbo-stream[action=update][target=daily_brief_day_dialog]"
    assert_select "turbo-stream[action=update][target=daily_brief_week] template" do
      assert_select "td", text: "Listen first"
      assert_select "[autofocus]", count: 1 do
        assert_select "[aria-label=?]", "Edit Tuesday"
      end
    end
    assert_select "turbo-stream[action=prepend][targets='main .container-xl'] template", text: /Tuesday saved\./
    @tuesday.reload
    assert_equal [ "Luke", "Mary", "Listen first" ], [ @tuesday.reading, @tuesday.examples, @tuesday.topic_for(@areas["As a husband"]) ]
  end

  test "in the week's frame the dialog saves with Turbo; opened on its own, in a new tab, it saves without" do
    get edit_household_daily_brief_plan_day_path(household_id: @home, wday: 2), headers: { "Turbo-Frame" => "daily_brief_day_dialog" }
    assert_select "dialog form[data-turbo=true]"

    get edit_household_daily_brief_plan_day_path(household_id: @home, wday: 2)
    assert_select "dialog form[data-turbo=false]"
  end

  test "update without Turbo goes back to the plan" do
    patch household_daily_brief_plan_day_path(household_id: @home, wday: 2), params: { daily_brief_day: { reading: "Luke" } }

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_equal "Tuesday saved.", flash[:notice]
    assert_equal "Luke", @tuesday.reload.reading
  end

  test "a blank box removes the topic, and a blank reading or examples leaves the brief to choose" do
    patch household_daily_brief_plan_day_path(household_id: @home, wday: 2),
          params: { daily_brief_day: { reading: "", examples: " ",
                                       topics: { @areas["As a father"].id => "", @areas["Qualities to focus on"].id => "Patience" } } }

    @tuesday.reload
    assert_nil @tuesday.reading
    assert_nil @tuesday.examples
    assert_nil @tuesday.topic_for(@areas["As a father"])
    assert_equal({ @areas["Qualities to focus on"].id => "Patience", @areas["Reaching out"].id => "Serious (v. 8)" },
                 @tuesday.topics)
  end

  test "a topic for a focus area the dialog didn't show is kept" do
    patch household_daily_brief_plan_day_path(household_id: @home, wday: 2),
          params: { daily_brief_day: { reading: "Luke", topics: { @areas["As a husband"].id => "Listen first" } } }

    @tuesday.reload
    assert_equal "Listen first", @tuesday.topic_for(@areas["As a husband"])
    assert_equal "Patience, Mildness", @tuesday.topic_for(@areas["Qualities to focus on"])
    assert_equal "Patient teaching of my children", @tuesday.topic_for(@areas["As a father"])
  end

  test "a refused update re-renders the dialog with :unprocessable_content" do
    patch household_daily_brief_plan_day_path(household_id: @home, wday: 2), params: { daily_brief_day: { examples: "a" * 201 } }

    assert_response :unprocessable_content
    assert_select "dialog[open] h1", "Edit Tuesday"
    assert_select "dialog[open]", text: /is too long/
    assert_equal "Abraham, Moses", @tuesday.reload.examples
  end

  test "a topic for another person's focus area is refused" do
    theirs = DailyBrief::Plan.start(users(:spouse), starter: "wife_and_mother").focus_areas.first

    patch household_daily_brief_plan_day_path(household_id: @home, wday: 2), params: { daily_brief_day: { topics: { theirs.id => "Mine now" } } }

    assert_response :unprocessable_content
    assert_select "dialog[open] .Banner", text: /can only be for your own focus areas/
    assert_equal "Patience, Mildness", @tuesday.reload.topic_for(@areas["Qualities to focus on"])
  end

  test "a wday of 7, or one that only starts with a day, is a 404" do
    # Built by hand, as the route helpers refuse a wday outside 0 to 6.
    [ "7", "2-not-a-day" ].each do |wday|
      path = household_daily_brief_plan_day_path(household_id: @home, wday: 2).sub(%r{/2\z}, "/#{wday}")

      get "#{path}/edit"
      assert_response :not_found

      sign_in identities(:head)
      patch path, params: { daily_brief_day: { reading: "Luke" } }
      assert_response :not_found
      sign_in identities(:head)
    end
    assert_equal "Matthew – John", @tuesday.reload.reading
  end

  test "someone with no plan gets a 404" do
    sign_in identities(:spouse)

    get edit_household_daily_brief_plan_day_path(household_id: @home, wday: 2)

    assert_response :not_found
  end

  test "a child is refused" do
    sign_in identities(:eli)

    get edit_household_daily_brief_plan_day_path(household_id: @home, wday: 2)
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]

    patch household_daily_brief_plan_day_path(household_id: @home, wday: 2), params: { daily_brief_day: { reading: "Luke" } }
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "Matthew – John", @tuesday.reload.reading
  end

  test "the week has an Edit link per row, labelled with the day" do
    get household_daily_brief_plan_path(household_id: @home)

    Date::DAYNAMES.each_with_index do |day, wday|
      assert_select "#daily_brief_week tbody a[aria-label=?][href=?][data-turbo-frame=daily_brief_day_dialog]", "Edit #{day}",
                    edit_household_daily_brief_plan_day_path(household_id: @home, wday:), text: "Edit"
    end
  end
end
