require "test_helper"

class MeetingPreps::CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Tuesday of the week of 9 November, whose talk and Bible Reading cards are in prep_week_cards.yml.
    travel_to Time.utc(2026, 11, 10, 16)
    @home = households(:home)
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_helper(by: users(:head))
    @home.enable_meeting_prep(by: users(:head))
  end

  test "a card for the child: the part, Card N of M, the step's icon, what it's about, the quality and I can" do
    sign_in identities(:eli)

    get card_path("talk")

    assert_response :success
    assert_select "body[data-color-mode=dark]"
    assert_select "header", text: /Midweek meeting/
    assert_select "header .sr-only", "Card 1 of 2: Treasures From God's Word"
    assert_select "header .meeting-helper__dot", count: 2
    assert_select "main", text: /Treasures From God's Word · Card 1 of 2/
    assert_select "main .meeting-helper__icon svg[aria-hidden=true]"
    assert_select "main h1", "Jeremiah felt very sad. But he remembered that Jehovah never stops caring."
    assert_select "main .meeting-prep__quality" do
      assert_select "h2", "Jehovah cares"
      assert_select "p", "His kindness is new every morning."
      assert_select "svg[aria-hidden=true]"
    end
    assert_select "main .meeting-prep__i-can" do
      assert_select "h2", "I can…"
      assert_select "p", "Tell Jehovah when I feel sad."
    end
    assert_select "main .meeting-prep__story", count: 0
  end

  test "Back from the first card goes to Get ready, and Next card to the next" do
    sign_in identities(:eli)

    get card_path("talk")

    assert_select "main a[href='#{household_meeting_preps_path(household_id: @home)}']", "Back"
    assert_select "main a[href='#{card_path("bible_reading")}']", "Next card"
  end

  test "the Bible Reading card: the story with its reading, and All done on the last card" do
    sign_in identities(:eli)

    get card_path("bible_reading")

    assert_response :success
    assert_select "main h1.meeting-prep__heading--reading", "A sad song about Jerusalem."
    assert_select "main .meeting-prep__story" do
      assert_select "h2", "The story · Lamentations 1–2"
      assert_select "ol li", count: 2
      assert_select "ol li:first-child", text: /Jerusalem was the city where Jehovah’s people lived./
    end
    assert_select "main a[href='#{card_path("talk")}']", "Back"
    assert_select "main a[href='#{household_meeting_preps_path(household_id: @home)}']", "All done"
    assert_select "main a", text: "Next card", count: 0
  end

  test "the Bible Reading card without a story (a parent cleared it) has no story box" do
    prep_week_cards(:home_nov_9_bible_reading).update!(story: nil, reading: nil)
    sign_in identities(:eli)

    get card_path("bible_reading")

    assert_response :success
    assert_select "main .meeting-prep__story", count: 0
  end

  test "card text is escaped" do
    prep_week_cards(:home_nov_9_talk).update!(about: "<b>Bold</b> words", i_can: "<script>alert(1)</script>")
    sign_in identities(:eli)

    get card_path("talk")

    assert_select "main h1", "<b>Bold</b> words"
    assert_select "main h1 b", count: 0
    assert_select "main script", count: 0
  end

  test "a step with no card is a 404" do
    [ card_path("living"), household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "weekend", id: "talk") ].each do |path|
      sign_in identities(:eli)

      get path

      assert_response :not_found, "expected a 404 at #{path}"
    end
  end

  test "a week with no cards is a 404" do
    travel_to Time.utc(2026, 11, 17, 12)
    sign_in identities(:eli)

    get card_path("talk")

    assert_response :not_found
  end

  test "a head or an adult on a card is a 404" do
    %i[ head spouse ].each do |identity|
      sign_in identities(identity)

      get card_path("talk")

      assert_response :not_found
    end
  end

  test "a child with Get ready off is a 404" do
    @home.disable_meeting_prep
    sign_in identities(:eli)

    get card_path("talk")

    assert_response :not_found
  end

  test "a child with the helper off is a 404" do
    @home.disable_meeting_helper
    sign_in identities(:eli)

    get card_path("talk")

    assert_response :not_found
  end

  private
    def card_path(step)
      household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "midweek", id: step)
    end
end
