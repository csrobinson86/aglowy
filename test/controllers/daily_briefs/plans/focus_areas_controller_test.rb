require "test_helper"

class DailyBriefs::Plans::FocusAreasControllerTest < ActionDispatch::IntegrationTest
  CAPTION = "Sent to the AI as you type it. Leave out names."

  setup do
    @home = households(:home)
    @plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    sign_in identities(:head)
  end

  test "new is a blank dialog, a role, with Add focus area" do
    get new_household_daily_brief_plan_focus_area_path(household_id: @home)

    assert_response :success
    assert_select "turbo-frame#daily_brief_focus_area_dialog dialog[open]" do
      assert_select "h1", "Add a focus area"
      assert_select "form[action=?]", household_daily_brief_plan_focus_areas_path(household_id: @home) do
        assert_select "input[name='daily_brief_focus_area[name]']:not([value])"
        assert_select "textarea[name='daily_brief_focus_area[gives]']", text: ""
        assert_select "input[name='daily_brief_focus_area[scriptures]']:not([value])"
        assert_select "input[type=hidden][name='daily_brief_focus_area[kind]'][value=role]"
        assert_select "button[type=submit]", "Add focus area"
      end
      assert_select "button", text: "Delete", count: 0
    end
  end

  test "the name and what-it-gives fields carry the Sent to the AI caption, and the scriptures don't" do
    get new_household_daily_brief_plan_focus_area_path(household_id: @home)

    assert_select ".FormControl-caption", text: CAPTION, count: 2
    %w[ name gives ].each do |field|
      caption_id = css_select("[name='daily_brief_focus_area[#{field}]']").first["aria-describedby"].split.find { it.start_with?("caption-") }
      assert_select "##{caption_id}", text: CAPTION
    end
  end

  test "new from each library key fills the form from the library" do
    users(:head).daily_brief_plan.destroy!
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    plan.focus_areas.delete_all

    DailyBrief::FocusArea::Library.all.each do |entry|
      get new_household_daily_brief_plan_focus_area_path(household_id: @home, from: entry.key)

      assert_response :success
      assert_select "input[name='daily_brief_focus_area[name]'][value=?]", entry.name
      assert_select "textarea[name='daily_brief_focus_area[gives]']", text: entry.gives
      assert_select "input[name='daily_brief_focus_area[scriptures]'][value=?]", entry.scriptures
      assert_select "input[type=hidden][name='daily_brief_focus_area[kind]'][value=?]", entry.kind
    end
  end

  test "a second quality or appreciation isn't offered: not as a chip, and new from its key is a blank role" do
    get household_daily_brief_plan_path(household_id: @home)

    assert_select "a[href=?]", new_household_daily_brief_plan_focus_area_path(household_id: @home, from: "ministry"), text: "In the ministry"
    assert_select "a[href=?]", new_household_daily_brief_plan_focus_area_path(household_id: @home, from: "qualities"), count: 0
    assert_select "a[href=?]", new_household_daily_brief_plan_focus_area_path(household_id: @home, from: "appreciation"), count: 0
    assert_select "a[href=?]", new_household_daily_brief_plan_focus_area_path(household_id: @home, from: "husband"), count: 0

    get new_household_daily_brief_plan_focus_area_path(household_id: @home, from: "qualities")

    assert_select "input[name='daily_brief_focus_area[name]']:not([value])"
    assert_select "input[type=hidden][name='daily_brief_focus_area[kind]'][value=role]"
  end

  test "create adds it at the end and closes the dialog" do
    assert_difference -> { @plan.focus_areas.count } do
      post household_daily_brief_plan_focus_areas_path(household_id: @home), as: :turbo_stream,
           params: { daily_brief_focus_area: { kind: "role", name: "In the ministry", gives: "One way to share in the ministry today.",
                                               scriptures: "Matthew 28:19, 20" } }
    end

    assert_response :success
    assert_select "turbo-stream[action=update][target=daily_brief_focus_area_dialog]"
    assert_select "turbo-stream[action=replace][target=daily_brief_focus_areas] template li h3", text: "In the ministry"
    assert_select "turbo-stream[action=update][target=daily_brief_week] template th", text: "In the ministry"
    assert_select "turbo-stream[action=prepend][targets='main .container-xl'] template", text: /Focus area added\./
    assert_select "turbo-stream[action=refresh]", count: 0
    area = @plan.focus_areas.reload.last
    assert_equal [ "In the ministry", "role", 5, "Matthew 28:19, 20" ], [ area.name, area.kind, area.position, area.scriptures ]
  end

  test "create without Turbo goes back to the plan" do
    post household_daily_brief_plan_focus_areas_path(household_id: @home),
         params: { daily_brief_focus_area: { kind: "role", name: "At work", gives: "One honest thing.", scriptures: "" } }

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_equal "Focus area added.", flash[:notice]
  end

  test "a refused create re-renders the dialog with :unprocessable_content" do
    assert_no_difference -> { DailyBrief::FocusArea.count } do
      post household_daily_brief_plan_focus_areas_path(household_id: @home),
           params: { daily_brief_focus_area: { kind: "role", name: "", gives: "One way.", scriptures: "Hezekiah 3:1" } }
    end

    assert_response :unprocessable_content
    assert_select "dialog[open] h1", "Add a focus area"
    assert_select "dialog[open]", text: /can't be blank/
    assert_select "dialog[open]", text: /has a reference that isn't a Bible verse: Hezekiah 3:1/
  end

  test "a second quality sent anyway is refused" do
    assert_no_difference -> { DailyBrief::FocusArea.count } do
      post household_daily_brief_plan_focus_areas_path(household_id: @home),
           params: { daily_brief_focus_area: { kind: "quality", name: "Kindness", gives: "One way to be kind." } }
    end

    assert_response :unprocessable_content
    assert_select "dialog[open]", text: /You already have a quality focus area/
  end

  test "a seventh is refused, and the plan offers no more once it has six" do
    @plan.focus_areas.create!(kind: "role", name: "At work", gives: "One honest thing.")

    get household_daily_brief_plan_path(household_id: @home)
    assert_select "a", text: "Add a focus area", count: 0
    assert_select "a[href^=?]", new_household_daily_brief_plan_focus_area_path(household_id: @home), count: 0
    assert_select "main", text: /six focus areas, the most a plan can have/

    assert_no_difference -> { DailyBrief::FocusArea.count } do
      post household_daily_brief_plan_focus_areas_path(household_id: @home),
           params: { daily_brief_focus_area: { kind: "role", name: "In the ministry", gives: "One way." } }
    end

    assert_response :unprocessable_content
    assert_select "dialog[open]", text: /You can have six focus areas at most/
  end

  test "edit is the dialog filled in, with Delete behind a confirm" do
    area = area_named("Reaching out")

    get edit_household_daily_brief_plan_focus_area_path(household_id: @home, id: area)

    assert_response :success
    assert_select "dialog[open]" do
      assert_select "h1", "Edit focus area"
      assert_select "form[action=?]", household_daily_brief_plan_focus_area_path(household_id: @home, id: area) do
        assert_select "input[name='daily_brief_focus_area[name]'][value='Reaching out']"
        assert_select "input[name='daily_brief_focus_area[kind]']", count: 0
        assert_select "button[type=submit]", "Save focus area"
      end
      assert_select ".FormControl-caption", text: CAPTION, count: 2
      assert_select "button[data-show-dialog-id]", "Delete"
    end
    assert_select "dialog:not([open])" do
      assert_select "h1", "Delete “Reaching out”?"
      assert_select "form[action=?] input[name=_method][value=delete]", household_daily_brief_plan_focus_area_path(household_id: @home, id: area)
      assert_select "button[type=submit]", "Delete focus area"
    end
  end

  test "update saves its name, what it gives and scriptures, never its kind" do
    area = area_named("Reaching out")

    patch household_daily_brief_plan_focus_area_path(household_id: @home, id: area), as: :turbo_stream,
          params: { daily_brief_focus_area: { name: "Reaching out today", gives: "One reliable thing.", scriptures: "1 Timothy 3:8", kind: "quality" } }

    assert_response :success
    assert_select "turbo-stream[action=replace][target=daily_brief_focus_areas] template h3", text: "Reaching out today"
    area.reload
    assert_equal [ "Reaching out today", "One reliable thing.", "1 Timothy 3:8", "role" ], [ area.name, area.gives, area.scriptures, area.kind ]
  end

  test "a refused update re-renders the dialog with :unprocessable_content" do
    area = area_named("Reaching out")

    patch household_daily_brief_plan_focus_area_path(household_id: @home, id: area),
          params: { daily_brief_focus_area: { name: "a" * 61, gives: "One way." } }

    assert_response :unprocessable_content
    assert_select "dialog[open] h1", "Edit focus area"
    assert_select "dialog[open]", text: /is too long/
    assert_equal "Reaching out", area.reload.name
  end

  test "destroy removes it and its topics from the week" do
    area = area_named("Reaching out")

    assert_difference -> { @plan.focus_areas.count }, -1 do
      delete household_daily_brief_plan_focus_area_path(household_id: @home, id: area)
    end

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_equal "Focus area deleted.", flash[:notice]
    assert @plan.days.reload.none? { it.topics.key?(area.id) }
  end

  test "another person's focus area is a 404" do
    theirs = DailyBrief::Plan.start(users(:spouse), starter: "wife_and_mother").focus_areas.first

    # A 404 doesn't keep the session, so each request signs in again.
    get edit_household_daily_brief_plan_focus_area_path(household_id: @home, id: theirs)
    assert_response :not_found

    sign_in identities(:head)
    patch household_daily_brief_plan_focus_area_path(household_id: @home, id: theirs), params: { daily_brief_focus_area: { name: "Mine now" } }
    assert_response :not_found

    sign_in identities(:head)
    assert_no_difference -> { DailyBrief::FocusArea.count } do
      delete household_daily_brief_plan_focus_area_path(household_id: @home, id: theirs)
    end
    assert_response :not_found
    assert_equal "As a wife", theirs.reload.name
  end

  test "someone with no plan gets a 404" do
    sign_in identities(:spouse)

    get new_household_daily_brief_plan_focus_area_path(household_id: @home)

    assert_response :not_found
  end

  test "a child is refused" do
    sign_in identities(:eli)

    get new_household_daily_brief_plan_focus_area_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]

    post household_daily_brief_plan_focus_areas_path(household_id: @home),
         params: { daily_brief_focus_area: { kind: "role", name: "At school", gives: "One way." } }
    assert_redirected_to household_root_path(household_id: @home)

    delete household_daily_brief_plan_focus_area_path(household_id: @home, id: @plan.focus_areas.first)
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal 5, @plan.focus_areas.count
  end

  private
    def area_named(name)
      @plan.focus_areas.find { it.name == name }
    end
end
