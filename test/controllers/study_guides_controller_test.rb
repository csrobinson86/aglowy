require "test_helper"

# The study guide's pages (docs/design/study-guide.md, Pages and routes): this week's guide, or the not-made-yet state,
# and a week's guide a meeting at a time. Hannah's guide for the week of 9 November has the talk and the weekend
# overview (study_guide_parts.yml); it's Tuesday of that week.
class StudyGuidesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @guide = study_guides(:head_nov_9)
    travel_to Time.utc(2026, 11, 10, 16)
    sign_in identities(:head)
  end

  test "index redirects to this week's guide" do
    get household_study_guides_path(household_id: @home)

    assert_redirected_to household_study_guide_path(household_id: @home, week_of: "2026-11-09")
  end

  test "index says this week's isn't ready yet, and lists the kept weeks" do
    travel_to Time.utc(2026, 11, 17, 16)

    get household_study_guides_path(household_id: @home)

    assert_response :success
    assert_select "main", text: /Your study guide is made early on Monday. This week's isn't ready yet./
    assert_select "a[href=?]", household_study_guide_path(household_id: @home, week_of: "2026-11-09"), text: /November 9/
  end

  test "show is the owner's midweek, with Midweek current and the parts it has" do
    User::WeeklyStudyGuide.create!(user: users(:head))

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :success
    assert_select "h1", /Study guide/
    assert_select "h1 .Label", "Private"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Study guide"
    assert_select ".SegmentedControl a[aria-current='true']", "Midweek"
    assert_select "h2", "Jehovah Keeps His Word"
    assert_select "main", text: /Some parts aren't ready yet. They'll be added when they are./
    assert_select "main", text: /The Watchtower Study is about patience at home./, count: 0
  end

  test "show with meeting=weekend is the weekend, with Weekend current" do
    get household_study_guide_path(household_id: @home, week_of: "2026-11-09", meeting: "weekend")

    assert_response :success
    assert_select ".SegmentedControl a[aria-current='true']", "Weekend"
    assert_select "main", text: /The Watchtower Study is about patience at home./
    assert_select "h2", text: "Jehovah Keeps His Word", count: 0
  end

  test "another person's week is a 404" do
    sign_in identities(:spouse)

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :not_found
  end

  test "a week with no guide is a 404, and so is a date that isn't one" do
    # A 404 doesn't save the session, so each request signs in again.
    %w[ 2026-11-16 2026-11-10 not-a-date ].each do |week_of|
      sign_in identities(:head)
      get household_study_guide_path(household_id: @home, week_of:)

      assert_response :not_found, "expected #{week_of} to be a 404"
    end
  end

  test "a child membership is a 404, even with a guide of their own" do
    users(:eli).study_guides.create!(week_of: "2026-11-09")
    sign_in identities(:eli)

    get household_study_guides_path(household_id: @home)
    assert_response :not_found

    sign_in identities(:eli)
    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")
    assert_response :not_found
  end
end
