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

  # The children's Get ready cards beside each part (docs/design/study-guide.md, The children's card; Trap 4): last
  # week's talk and Bible Reading cards are in prep_week_cards.yml.
  test "show, with Get ready on and cards: each matching part shows its card, read-only with Change" do
    enable_get_ready
    @guide.parts.create!(step: "bible_reading", content: { "reading" => "Lamentations 1–2", "summary" => "Jeremiah mourns Jerusalem." })

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :success
    assert_select ".study-guide-prep-card", count: 2
    assert_select ".study-guide-part", text: /Jehovah Keeps His Word/ do
      assert_select ".study-guide-prep-card" do
        assert_select "*", text: /For Eli · from Get ready/
        assert_select "*", text: /Jeremiah felt very sad. But he remembered that Jehovah never stops caring./
        assert_select "*", text: /Jehovah cares/
        assert_select "*", text: /I can\s+Tell Jehovah when I feel sad./
        assert_select "a[href=?][data-turbo-frame=meeting_prep_card_dialog]",
          edit_household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "midweek", id: "talk"), "Change"
        assert_select "input, textarea, form", count: 0
      end
    end
    assert_select ".study-guide-part", text: /The Bible reading/ do
      assert_select ".study-guide-prep-card", text: /A sad song about Jerusalem.\s+Jehovah is fair\s+·\s+I can\s+Listen when Mom and Dad warn me./
    end
    assert_select "turbo-frame#meeting_prep_card_dialog"
  end

  test "show, with no child here who signs in, says the card is from Get ready without naming anyone" do
    enable_get_ready
    identities(:eli).destroy!

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :success
    assert_select ".study-guide-prep-card__kicker", count: 1, text: "From Get ready"
  end

  test "show, with Get ready off here, has no children's cards" do
    @home.enable_meeting_helper(by: users(:head))

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :success
    assert_select "h2", "Jehovah Keeps His Word"
    assert_select ".study-guide-prep-card", count: 0
    assert_select "main", text: /from Get ready/, count: 0
  end

  test "show: a part without a card, Spiritual Gems and the overview, have none" do
    enable_get_ready
    prep_week_cards(:home_nov_9_bible_reading).destroy!
    @guide.parts.create!(step: "bible_reading", content: { "reading" => "Lamentations 1–2", "summary" => "Jeremiah mourns Jerusalem." })
    @guide.parts.create!(step: "spiritual_gems", content: { "summary" => "Short comments.", "comments" => [ { "text" => "One." }, { "text" => "Two." } ] })
    @guide.parts.create!(step: "midweek_overview", content: { "glance" => "Jeremiah grieves over Jerusalem.",
                                                                 "jehovah" => [ { "quality" => "Merciful", "text" => "He still hears his people." } ] })

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :success
    assert_select ".study-guide-prep-card", count: 1
    assert_select ".study-guide-part", text: /Jehovah Keeps His Word/ do
      assert_select ".study-guide-prep-card", count: 1
    end
    assert_select ".study-guide-part", text: /The Bible reading/ do
      assert_select ".study-guide-prep-card", count: 0
    end
    assert_select ".study-guide-part", text: /Ideas for comments/ do
      assert_select ".study-guide-prep-card", count: 0
    end
    assert_select ".study-guide-glance .study-guide-prep-card", count: 0
  end

  test "show escapes the children's card text" do
    enable_get_ready
    prep_week_cards(:home_nov_9_talk).update!(about: "<b>Bold</b> words", i_can: "<i>Sing</i> loudly.")

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :success
    assert_select ".study-guide-prep-card", text: /<b>Bold<\/b> words/
    assert_select ".study-guide-prep-card", text: /<i>Sing<\/i> loudly./
    assert_select ".study-guide-prep-card b, .study-guide-prep-card i", count: 0
  end

  test "show, on the weekend, puts the Watchtower card on the Watchtower Study part" do
    enable_get_ready
    prep_weeks(:home_nov_9).cards.create!(meeting: "weekend", step: "watchtower_study", about: "Jehovah listens when we pray.",
                                          quality: "loving", quality_line: "He hears every prayer.", i_can: "Say a prayer before bed.")
    @guide.parts.create!(step: "watchtower_study", content: { "title" => "Be Patient at Home", "summary" => "The article is about patience." })

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09", meeting: "weekend")

    assert_response :success
    assert_select ".study-guide-prep-card", count: 1
    assert_select ".study-guide-part", text: /Be Patient at Home/ do
      assert_select ".study-guide-prep-card", text: /Jehovah listens when we pray.\s+Jehovah is loving\s+·\s+I can\s+Say a prayer before bed./
      assert_select "a[href=?]", edit_household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "weekend", id: "watchtower_study"), "Change"
    end
  end

  test "show takes the cards from the household in the URL, never from the guide" do
    enable_get_ready

    get household_study_guide_path(household_id: households(:parents), week_of: "2026-11-09")

    assert_response :success
    assert_select "h2", "Jehovah Keeps His Word"
    assert_select ".study-guide-prep-card", count: 0
  end

  test "show, for an earlier week, shows that week's card without Change, which changes only this week's" do
    enable_get_ready
    travel_to Time.utc(2026, 11, 17, 16)

    get household_study_guide_path(household_id: @home, week_of: "2026-11-09")

    assert_response :success
    assert_select ".study-guide-prep-card", text: /Tell Jehovah when I feel sad./
    assert_select ".study-guide-prep-card a", count: 0
    assert_select "turbo-frame#meeting_prep_card_dialog", count: 0
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

  private
    def enable_get_ready
      @home.enable_meeting_helper(by: users(:head))
      @home.enable_meeting_prep(by: users(:head))
    end
end
