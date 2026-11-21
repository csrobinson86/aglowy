require "test_helper"

class MeetingPrepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Tuesday of the week of 9 November, whose talk and Bible Reading cards are in prep_week_cards.yml.
    travel_to Time.utc(2026, 11, 10, 16)
    @home = households(:home)
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_helper(by: users(:head))
    @home.enable_meeting_prep(by: users(:head))
  end

  test "index, for the child: a tile per meeting, next first, in the helper's layout" do
    sign_in identities(:eli)

    get household_meeting_preps_path(household_id: @home)

    assert_response :success
    assert_select "body[data-color-mode=dark]"
    assert_select "header", text: /Week of November 9/
    assert_select "main h1", "Get ready for the meetings"
    assert_select "main", text: /Ask Mom or Dad to read the cards with you./
    assert_select "main .meeting-prep__tile", count: 2
    assert_select "main .meeting-prep__tile:first-of-type" do
      assert_select "h2", "Midweek meeting"
      assert_select "*", text: /Thursday · 7:00 PM/
      assert_select "*", text: /2 cards/
      assert_select "a[href='#{household_meeting_prep_path(household_id: @home, meeting: "midweek")}']", "Start"
    end
    assert_select "main .meeting-prep__tile:last-of-type" do
      assert_select "h2", "Weekend meeting"
      assert_select "*", text: /Sunday · 10:00 AM/
      assert_select "*", text: /Cards aren't ready yet/
      assert_select "a", count: 0
    end
  end

  test "index, once the meeting's note has her comment: My comment is ready" do
    users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9)).write_answer(paragraph: 7, body: "Jehovah helps us.")
    users(:eli).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9))
    sign_in identities(:eli)

    get household_meeting_preps_path(household_id: @home)

    assert_select "main .meeting-prep__tile:first-of-type" do
      assert_select "*", text: /My comment is ready/
      assert_select "*", text: /2 cards/, count: 0
    end
    assert_select "main .meeting-prep__tile:last-of-type", text: /My comment is ready/, count: 0
  end

  test "index, once the midweek meeting has passed: the weekend first, and Look again on the midweek" do
    travel_to Time.utc(2026, 11, 13, 12)
    sign_in identities(:eli)

    get household_meeting_preps_path(household_id: @home)

    assert_select "main .meeting-prep__tile:first-of-type h2", "Weekend meeting"
    assert_select "main .meeting-prep__tile:last-of-type" do
      assert_select "h2", "Midweek meeting"
      assert_select "a", "Look again"
    end
  end

  test "index with no cards this week: every meeting says Cards aren't ready yet" do
    travel_to Time.utc(2026, 11, 17, 12)
    sign_in identities(:eli)

    get household_meeting_preps_path(household_id: @home)

    assert_response :success
    assert_select "main .meeting-prep__tile", text: /Cards aren't ready yet/, count: 2
    assert_select "main .meeting-prep__tile a", count: 0
  end

  test "show redirects to the meeting's first card" do
    sign_in identities(:eli)

    get household_meeting_prep_path(household_id: @home, meeting: "midweek")

    assert_redirected_to household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "midweek", id: "talk")
  end

  test "show redirects to Get ready when the meeting has no cards" do
    sign_in identities(:eli)

    get household_meeting_prep_path(household_id: @home, meeting: "weekend")

    assert_redirected_to household_meeting_preps_path(household_id: @home)
  end

  test "show for a meeting that isn't midweek or weekend is a 404" do
    sign_in identities(:eli)

    get household_meeting_prep_path(household_id: @home, meeting: "assembly")

    assert_response :not_found
  end

  test "show is a 404 for a head or an adult" do
    %i[ head spouse ].each do |identity|
      sign_in identities(identity)

      get household_meeting_prep_path(household_id: @home, meeting: "midweek")

      assert_response :not_found, "expected #{identity} to get a 404"
    end
  end

  test "index, for a head: the week, who can see them, the sources, and a box per meeting with each card and Change" do
    prep_weeks(:home_nov_9).sources.create!(position: 1, title: "Life and Ministry Meeting Workbook, November 9-15", url: "https://wol.jw.org/en/wol/d/r1/lp-e/202026401")
    sign_in identities(:head)

    get household_meeting_preps_path(household_id: @home)

    assert_response :success
    assert_select "body[data-color-mode=dark]", count: 0
    assert_select "nav[aria-label='Sidebar']"
    assert_select "main h1", "This week's Get ready cards"
    assert_select "main", text: /Week of November 9–15, 2026/
    assert_select "main", text: /AI wrote these from this week's program. Eli can see them now. Change anything that isn't right./
    assert_select "main a[href='https://wol.jw.org/en/wol/d/r1/lp-e/202026401'][target=_blank]", text: /Life and Ministry Meeting Workbook, November 9-15/
    assert_select "#meeting-prep-midweek" do
      assert_select "h2", "Midweek meeting"
      assert_select "*", text: /2 cards/
      assert_select "#prep_week_card_#{prep_week_cards(:home_nov_9_talk).id}" do
        assert_select "*", text: /Treasures From God's Word/
        assert_select "*", text: /Jeremiah felt very sad. But he remembered that Jehovah never stops caring./
        assert_select "*", text: /Jehovah cares · I can: Tell Jehovah when I feel sad./
        assert_select "a[href='#{edit_household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "midweek", id: "talk")}']", "Change"
      end
      assert_select "#prep_week_card_#{prep_week_cards(:home_nov_9_bible_reading).id}", text: /Bible Reading · Lamentations 1–2/
    end
    assert_select "#meeting-prep-weekend" do
      assert_select "h2", "Weekend meeting"
      assert_select "*", text: /Cards aren't ready yet/
    end
  end

  test "index, for an adult, with two children who sign in: names them both, and escapes card text" do
    users(:child).create_identity!(username: "charlie", password: "password123", confirmed_at: Time.current)
    prep_week_cards(:home_nov_9_talk).update!(about: "<b>Bold</b> words")
    sign_in identities(:spouse)

    get household_meeting_preps_path(household_id: @home)

    assert_response :success
    assert_select "main", text: /Charlie and Eli can see them now./
    assert_select "main", text: /<b>Bold<\/b> words/
    assert_select "main b", count: 0
  end

  test "index, for a head, with no cards this week: Cards aren't ready yet" do
    users(:head).accept_ai_terms(understood: true)
    travel_to Time.utc(2026, 11, 17, 12)
    sign_in identities(:head)

    get household_meeting_preps_path(household_id: @home)

    assert_response :success
    assert_select "main h2", "Cards aren't ready yet"
    assert_select "main a", text: "Change", count: 0
  end

  test "index, for a head, when nobody has accepted the AI terms: a link to where they're accepted" do
    travel_to Time.utc(2026, 11, 17, 12)
    sign_in identities(:head)

    get household_meeting_preps_path(household_id: @home)

    assert_select "main h2", "Cards need a head or adult who has turned on AI features"
    assert_select "main a[href='#{new_household_family_study_path(household_id: @home)}']"
  end

  test "index is a 404 for a head with Get ready off" do
    @home.disable_meeting_prep
    sign_in identities(:head)

    get household_meeting_preps_path(household_id: @home)

    assert_response :not_found
  end

  test "index is a 404 for a child with Get ready off" do
    @home.disable_meeting_prep
    sign_in identities(:eli)

    get household_meeting_preps_path(household_id: @home)

    assert_response :not_found
  end

  test "index is a 404 for a child outside the household" do
    sign_in identities(:outsider)

    get household_meeting_preps_path(household_id: @home)

    assert_response :not_found
  end
end
