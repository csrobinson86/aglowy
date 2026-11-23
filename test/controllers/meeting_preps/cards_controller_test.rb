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

  test "the Bible Reading card's Draw it! posts to her note with to=drawing, between Back and Next" do
    sign_in identities(:eli)

    get card_path("bible_reading")

    assert_select "main nav form[action='#{note_path("midweek")}'][method=post]" do
      assert_select "input[type=hidden][name=to][value=drawing]"
      assert_select "button[type=submit]", text: "Draw it!"
    end
  end

  test "a card that isn't the Bible Reading or a study has no Draw it! and no comment box" do
    sign_in identities(:eli)

    get card_path("talk")

    assert_select "main form", count: 0
    assert_select "main .meeting-prep__comment", count: 0
  end

  test "the Bible Study card before she has a comment: My comment, the line, and Get my comment ready" do
    add_study_card
    sign_in identities(:eli)

    get card_path("congregation_bible_study")

    assert_select "main .meeting-prep__comment" do
      assert_select "h2", "My comment"
      assert_select "p", "Pick a paragraph with your family. Then say it your own way."
      assert_select "form[action='#{note_path("midweek")}'][method=post]" do
        assert_select "input[type=hidden][name=to][value=answer]"
        assert_select "button[type=submit]", text: "Get my comment ready"
      end
    end
  end

  test "the Bible Study card once she has a comment: the paragraph, her words escaped, and Change" do
    add_study_card
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    note.write_answer(paragraph: 7, body: "<b>Jehovah</b> helps us when we are sad.")
    sign_in identities(:eli)

    get card_path("congregation_bible_study")

    assert_select "main .meeting-prep__comment" do
      assert_select "h2", "My comment · paragraph 7"
      assert_select "p", "<b>Jehovah</b> helps us when we are sad."
      assert_select "b", count: 0
      assert_select "a[href='#{edit_household_meeting_note_step_answer_path(household_id: @home, meeting_note_id: note, step_id: "congregation_bible_study", from: "prep")}']", text: "Change"
      assert_select "form", count: 0
    end
  end

  test "another week's comment isn't this week's" do
    add_study_card
    users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 2)).write_answer(paragraph: 3, body: "Last week.")
    sign_in identities(:eli)

    get card_path("congregation_bible_study")

    assert_select "main .meeting-prep__comment h2", "My comment"
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

  # Change a card, for heads and adults (docs/design/meeting-prep.md, Pages and routes; frame phone-prep-change.png).
  test "edit, for a head: a dialog with what it's about, Jehovah is… as a select of the ten, How it shows and I can…" do
    sign_in identities(:head)

    get edit_card_path("talk")

    assert_response :success
    assert_select "turbo-frame#meeting_prep_card_dialog dialog[open]" do
      assert_select "h1", "Treasures From God's Word"
      assert_select "form[action=?]", card_path("talk", week_of: "2026-11-09") do
        assert_select "textarea[name='prep_week_card_change[about]'][maxlength='160']", "Jeremiah felt very sad. But he remembered that Jehovah never stops caring."
        assert_select "select[name='prep_week_card_change[quality]'] option", count: 10
        assert_select "select[name='prep_week_card_change[quality]'] option[selected][value=caring]", "Jehovah cares"
        assert_select "input[name='prep_week_card_change[quality_line]'][value=?][maxlength='120']", "His kindness is new every morning."
        assert_select "input[name='prep_week_card_change[i_can]'][value=?][maxlength='120']", "Tell Jehovah when I feel sad."
        assert_select "input[name='prep_week_card_change[reading]']", count: 0
        assert_select "input[name^='prep_week_card_change[story_']", count: 0
        assert_select "button[type=submit]", "Save"
      end
    end
  end

  test "edit, the Bible Reading card: the reading and four story sentences" do
    sign_in identities(:spouse)

    get edit_card_path("bible_reading")

    assert_select "dialog[open] form" do
      assert_select "input[name='prep_week_card_change[reading]'][value=?][maxlength='40']", "Lamentations 1–2"
      assert_select "input[name='prep_week_card_change[story_1]'][value=?]", "Jerusalem was the city where Jehovah’s people lived."
      assert_select "input[name='prep_week_card_change[story_2]'][value=?]", "The people stopped listening to Jehovah."
      assert_select "input[name='prep_week_card_change[story_3]'][value='']"
      assert_select "input[name='prep_week_card_change[story_4]'][maxlength='120']"
    end
  end

  test "update, for a head: the card changes, changed_by is set, and the row is redrawn" do
    sign_in identities(:head)

    patch card_path("talk", week_of: "2026-11-09"), as: :turbo_stream, params: { prep_week_card_change: {
      about: " Jeremiah  was sad. ", quality: "loving", quality_line: "He stayed close.", i_can: "Hug my sister." } }

    assert_response :success
    card = prep_week_cards(:home_nov_9_talk).reload
    assert_equal [ "Jeremiah was sad.", "loving", "He stayed close.", "Hug my sister.", users(:head) ],
                 [ card.about, card.quality, card.quality_line, card.i_can, card.changed_by ]
    assert_nil card.reading
    assert_select "turbo-stream[action=update][target=meeting_prep_card_dialog]"
    assert_select "turbo-stream[action=update][target=prep_week_card_#{card.id}] template", text: /Jehovah is loving · I can: Hug my sister./
    # Or the card at the foot of the study guide's part, when Change was there.
    assert_select "turbo-stream[action=replace][target=study_guide_prep_week_card_#{card.id}] template", text: /Jehovah is loving\s+·\s+I can\s+Hug my sister./
  end

  test "update, without Turbo, goes back to Get ready" do
    sign_in identities(:spouse)

    patch card_path("talk", week_of: "2026-11-09"), params: { prep_week_card_change: {
      about: "Jeremiah was sad.", quality: "caring", quality_line: "He stayed close.", i_can: "Hug my sister." } }

    assert_redirected_to household_meeting_preps_path(household_id: @home)
    assert_equal "Card saved.", flash[:notice]
    assert_equal users(:spouse), prep_week_cards(:home_nov_9_talk).reload.changed_by
  end

  test "update, the Bible Reading card: blank sentences go, and a cleared reading and story are kept cleared" do
    sign_in identities(:head)

    patch card_path("bible_reading", week_of: "2026-11-09"), params: { prep_week_card_change: { about: "A sad song.", quality: "fair", quality_line: "He warned them.",
      i_can: "Listen.", reading: "Lamentations 1", story_1: "", story_2: " Jerusalem was sad. ", story_3: " ", story_4: "Jehovah still cared." } }

    card = prep_week_cards(:home_nov_9_bible_reading).reload
    assert_equal [ "Lamentations 1", [ "Jerusalem was sad.", "Jehovah still cared." ] ], [ card.reading, card.story ]

    patch card_path("bible_reading", week_of: "2026-11-09"), params: { prep_week_card_change: { about: "A sad song.", quality: "fair", quality_line: "He warned them.",
      i_can: "Listen.", reading: " ", story_1: "", story_2: "", story_3: "", story_4: "" } }

    assert_equal [ nil, nil ], card.reload.slice(:reading, :story).values
  end

  test "update with an unknown quality and a too-long field re-renders the dialog with each error by its field" do
    sign_in identities(:head)

    patch card_path("talk", week_of: "2026-11-09"), params: { prep_week_card_change: {
      about: "Jeremiah was sad.", quality: "brave", quality_line: "a" * 121, i_can: "Hug my sister." } }

    assert_response :unprocessable_content
    assert_select "dialog[open] select[name='prep_week_card_change[quality]'][aria-invalid=true]"
    assert_select "dialog[open] input[name='prep_week_card_change[quality_line]'][aria-invalid=true]"
    assert_select "dialog[open]", text: /is too long \(maximum is 120 characters\)/
    assert_select "dialog[open] [aria-invalid=true]", count: 2
    card = prep_week_cards(:home_nov_9_talk).reload
    assert_equal [ "caring", "Tell Jehovah when I feel sad.", nil ], [ card.quality, card.i_can, card.changed_by ]
  end

  test "update with a blank I can… or a story sentence over 120 characters is refused" do
    sign_in identities(:head)

    patch card_path("bible_reading", week_of: "2026-11-09"), params: { prep_week_card_change: {
      about: "A sad song.", quality: "fair", quality_line: "He warned them.", i_can: " ", reading: "Lamentations 1–2", story_1: "a" * 121 } }

    assert_response :unprocessable_content
    assert_select "dialog[open] input[name='prep_week_card_change[i_can]'][aria-invalid=true]"
    assert_select "dialog[open] input[name='prep_week_card_change[story_1]'][aria-invalid=true]"
    assert_equal "Listen when Mom and Dad warn me.", prep_week_cards(:home_nov_9_bible_reading).reload.i_can
  end

  test "card text is escaped in the dialog" do
    prep_week_cards(:home_nov_9_talk).update!(about: "<b>Bold</b> words")
    sign_in identities(:head)

    get edit_card_path("talk")

    assert_select "dialog textarea", "<b>Bold</b> words"
    assert_select "dialog b", count: 0
  end

  test "edit for a step with no card this week is a 404" do
    sign_in identities(:head)

    get edit_card_path("living")

    assert_response :not_found
  end

  test "a save from a dialog opened in another week, or naming no week, is a 404 and changes nothing" do
    [ card_path("talk", week_of: "2026-11-02"), card_path("talk") ].each do |path|
      sign_in identities(:head)

      patch path, params: { prep_week_card_change: { about: "Last week.", quality: "caring", quality_line: "Yes.", i_can: "Yes." } }

      assert_response :not_found, "expected a 404 at #{path}"
    end
    assert_nil prep_week_cards(:home_nov_9_talk).reload.changed_by
  end

  test "a child gets a 404 on edit and update" do
    sign_in identities(:eli)
    get edit_card_path("talk")
    assert_response :not_found

    sign_in identities(:eli) # A 404 from an exception sets no session cookie, so the test sign-in doesn't last.
    patch card_path("talk", week_of: "2026-11-09"), params: { prep_week_card_change: { about: "Changed.", quality: "caring", quality_line: "Yes.", i_can: "Yes." } }
    assert_response :not_found
    assert_equal "Tell Jehovah when I feel sad.", prep_week_cards(:home_nov_9_talk).reload.i_can
  end

  test "a head with Get ready off gets a 404 on edit and update" do
    @home.disable_meeting_prep
    sign_in identities(:head)
    get edit_card_path("talk")
    assert_response :not_found

    sign_in identities(:head)
    patch card_path("talk", week_of: "2026-11-09"), params: { prep_week_card_change: { about: "Changed.", quality: "caring", quality_line: "Yes.", i_can: "Yes." } }
    assert_response :not_found
    assert_nil prep_week_cards(:home_nov_9_talk).reload.changed_by
  end

  private
    def edit_card_path(step)
      edit_household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "midweek", id: step)
    end

    def card_path(step, **params)
      household_meeting_prep_card_path(household_id: @home, meeting_prep_meeting: "midweek", id: step, **params)
    end

    def note_path(meeting)
      household_meeting_prep_note_path(household_id: @home, meeting_prep_meeting: meeting)
    end

    def add_study_card
      prep_weeks(:home_nov_9).cards.create!(meeting: "midweek", step: "congregation_bible_study", about: "Jesus loved little children.",
                                            quality: "loving", quality_line: "Jesus showed us how Jehovah loves.", i_can: "Smile at the people.")
    end
end
