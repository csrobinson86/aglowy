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

  test "index and show are a 404 for a head or an adult" do
    %i[ head spouse ].product([ household_meeting_preps_path(household_id: @home),
                                household_meeting_prep_path(household_id: @home, meeting: "midweek") ]).each do |identity, path|
      sign_in identities(identity)

      get path

      assert_response :not_found, "expected #{identity} to get a 404 at #{path}"
    end
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
