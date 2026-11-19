require "test_helper"

class ListeningGamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # The home household's game is for the week of 9 November (listening_games.yml), with one talk round.
    travel_to Time.utc(2026, 11, 11, 12)
    households(:home).enable_meeting_helper(by: users(:head))
  end

  test "a head sees this week's game: the note with a link to each source, and a box per step with each round and Change" do
    second = listening_round("talk", 2, answer: "Tears", others: [ "A rainbow", "A lion", "A boat" ], kind: "feeling")
    reading = listening_round("bible_reading", 1, answer: "Lamentations", others: %w[ Genesis Psalms Jonah ], kind: "book")
    sign_in identities(:head)

    get household_listening_game_path(household_id: households(:home))

    assert_response :success
    assert_select "main h1", "This week's listening game"
    assert_select "main", text: /Midweek meeting · Week of November 9–15, 2026/
    assert_select "main", text: /AI found these from this week's program/
    assert_select "main a[href='#{listening_game_sources(:home_program).url}']", text: /Life and Ministry Meeting Workbook, November 9-15/
    assert_select "main section#listening-game-talk" do
      assert_select "h2", /Treasures From God's Word/
      assert_select "*", text: /2 rounds/
      assert_select "#listening_game_round_#{listening_game_rounds(:home_talk_first).id}", text: /Jeremiah\s+Noah · Moses · Daniel/
      assert_select "#listening_game_round_#{second.id}", text: /Tears\s+A rainbow · A lion · A boat/
      assert_select "a[href='#{edit_household_listening_game_round_path(household_id: households(:home), id: second)}']", "Change"
    end
    assert_select "main section#listening-game-bible_reading" do
      assert_select "h2", /Bible Reading/
      assert_select "*", text: /1 round\b/
      assert_select "#listening_game_round_#{reading.id}", text: /Lamentations\s+Genesis · Psalms · Jonah/
    end
    assert_select "main section#listening-game-spiritual_gems", count: 0
    assert_select "turbo-frame#listening_game_round_dialog"
  end

  test "an adult sees it too" do
    sign_in identities(:spouse)

    get household_listening_game_path(household_id: households(:home))

    assert_response :success
    assert_select "main h1", "This week's listening game"
  end

  test "the page is kept out of Turbo's snapshot cache and the browser's, so Back can't show the answers to a child who signs in next" do
    sign_in identities(:head)

    get household_listening_game_path(household_id: households(:home))

    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "a label with markup shows as text" do
    listening_round("talk", 2, answer: "<script>alert(1)</script>", others: [ "A rainbow", "A lion", "A boat" ])
    sign_in identities(:head)

    get household_listening_game_path(household_id: households(:home))

    assert_select "main script", count: 0
    assert_select "main", text: /<script>alert\(1\)<\/script>/
  end

  test "with no game this week and an adult who has turned on AI features: Cards for this week aren't ready yet" do
    travel_to Time.utc(2026, 11, 18, 12)
    users(:spouse).accept_ai_terms(understood: true)
    sign_in identities(:head)

    get household_listening_game_path(household_id: households(:home))

    assert_response :success
    assert_select "main h1", "This week's listening game"
    assert_select "main h2", "Cards for this week aren't ready yet"
    assert_select "main section[id^=listening-game-]", count: 0
  end

  test "a week across two months names both" do
    travel_to Time.utc(2026, 12, 2, 12)
    sign_in identities(:head)

    get household_listening_game_path(household_id: households(:home))

    assert_select "main", text: /Week of November 30 – December 6, 2026/
  end

  test "with no game and nobody who has turned on AI features: Cards need a head or adult who has, with a link to where" do
    travel_to Time.utc(2026, 11, 18, 12)
    sign_in identities(:head)

    get household_listening_game_path(household_id: households(:home))

    assert_select "main h2", "Cards need a head or adult who has turned on AI features"
    assert_select "main a[href='#{new_household_family_study_path(household_id: households(:home))}']"
    assert_select "main h2", text: "Cards for this week aren't ready yet", count: 0
  end

  test "a child gets a 404" do
    sign_in identities(:eli)

    get household_listening_game_path(household_id: households(:home))

    assert_response :not_found
  end

  test "the helper off is a 404" do
    households(:home).disable_meeting_helper
    sign_in identities(:head)

    get household_listening_game_path(household_id: households(:home))

    assert_response :not_found
  end

  test "another household is a 404" do
    sign_in identities(:outsider)

    get household_listening_game_path(household_id: households(:home))

    assert_response :not_found
  end
end
