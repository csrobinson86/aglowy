require "test_helper"

class MeetingPartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @part = meeting_parts(:head_conversation)
  end

  def part_params(**attributes)
    { kind: "following_up", meeting_on: "2026-12-03", minutes: "4", setting: "informal_witnessing",
      topic: "Return to someone who asked about prayer.", study_point: "lmd lesson 4 point 2", assistant: "Ana Ortiz", **attributes }
  end

  test "index lists only the signed-in person's parts, coming up then earlier, each Private" do
    sign_in identities(:head)

    get household_meeting_parts_path(household_id: @home)

    assert_response :success
    assert_select "title", "Meeting parts · The Head Family · Aglowy"
    assert_select "h1", "Meeting parts"
    assert_select "main", text: /Your student parts in Apply Yourself to the Field Ministry. Private unless you share them./
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Meeting parts"
    assert_select "a[href=?][data-turbo-frame=meeting_part_dialog]", new_household_meeting_part_path(household_id: @home), text: "Add a part"
    assert_select "section[aria-labelledby=coming-up] li", count: 1 do |row|
      assert_select row, "a[href=?]", household_meeting_part_path(household_id: @home, id: @part), text: "Starting a Conversation"
      assert_select row, "*", text: /hope for the future/
      assert_select row, "*", text: /3 min · House to house · with Ana Ortiz/
      assert_select row, ".Label", "Private"
    end
    assert_select "section[aria-labelledby=earlier] li", count: 1 do |row|
      assert_select row, "a", text: "Making Disciples"
      assert_select row, "*", text: /5 min/
    end
    assert_select "main", text: /Why we can trust the Bible/, count: 0
    assert_select "main", text: /real friend/, count: 0
  end

  test "with no parts, the list is a Blankslate offering Add a part" do
    sign_in identities(:grandparent)

    get household_meeting_parts_path(household_id: households(:parents))

    assert_select ".blankslate", text: /No parts yet/ do
      assert_select "*", text: /When you're given a part in Apply Yourself to the Field Ministry, add it here to prepare./
      assert_select "a[data-turbo-frame=meeting_part_dialog]", "Add a part"
    end
    assert_select "section[aria-labelledby=coming-up]", count: 0
  end

  test "create adds a part for the signed-in person and closes the dialog" do
    sign_in identities(:head)

    assert_difference -> { users(:head).meeting_parts.count } do
      post household_meeting_parts_path(household_id: @home), params: { meeting_part: part_params(user_id: users(:spouse).id) }, as: :turbo_stream
    end

    part = users(:head).meeting_parts.order(:created_at).last
    assert_equal [ "following_up", Date.new(2026, 12, 3), 4, "informal_witnessing" ], [ part.kind, part.meeting_on, part.minutes, part.setting ]
    assert_equal [ "Return to someone who asked about prayer.", "lmd lesson 4 point 2", "Ana Ortiz" ], [ part.topic, part.study_point, part.assistant ]
    assert_turbo_stream action: :update, target: "meeting_part_dialog"
    assert_turbo_stream action: :refresh
    assert_equal "Part added.", flash[:notice]
  end

  test "create without Turbo goes to the new part" do
    sign_in identities(:head)

    post household_meeting_parts_path(household_id: @home), params: { meeting_part: part_params }

    assert_redirected_to household_meeting_part_path(household_id: @home, id: users(:head).meeting_parts.order(:created_at).last)
  end

  test "a refused create shows the dialog again with :unprocessable_content" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingPart.count } do
      post household_meeting_parts_path(household_id: @home), params: { meeting_part: part_params(topic: "", minutes: "20") }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-frame#meeting_part_dialog dialog[open]" do
      assert_select "*", text: /Add a part/
      assert_select "textarea[name='meeting_part[topic]'][aria-invalid=true]"
      assert_select "input[name='meeting_part[minutes]'][aria-invalid=true]"
    end
  end

  test "the new form's date is the next midweek meeting day" do
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    sign_in identities(:head)

    travel_to Time.utc(2026, 11, 17, 12) do
      get new_household_meeting_part_path(household_id: @home)
    end

    assert_response :success
    assert_select "turbo-frame#meeting_part_dialog dialog[open]" do
      assert_select "input[name='meeting_part[meeting_on]'][value='2026-11-19']"
      assert_select "*", text: /Your next midweek meeting./
      assert_select "select[name='meeting_part[kind]'] option", count: 6
      assert_select "select[name='meeting_part[kind]'] option", text: "Explaining Your Beliefs (demonstration)"
      assert_select "select[name='meeting_part[kind]'] option", text: "Explaining Your Beliefs (talk)"
      assert_select "select[name='meeting_part[setting]'] option", text: "House to house"
      assert_select "*", text: /Type it in your own words. Aglowy doesn't copy the workbook./
    end
  end

  test "on the meeting day itself, the new form's date is today" do
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    sign_in identities(:head)

    travel_to Time.utc(2026, 11, 19, 21) do
      get new_household_meeting_part_path(household_id: @home)
    end

    assert_select "input[name='meeting_part[meeting_on]'][value='2026-11-19']"
  end

  test "the new form's date is blank without meeting times" do
    sign_in identities(:head)

    get new_household_meeting_part_path(household_id: @home)

    assert_select "input[name='meeting_part[meeting_on]']" do |input|
      assert_nil input.first["value"]
    end
    assert_select "*", text: /Your next midweek meeting./, count: 0
  end

  test "show is the part: its header, The part, Preparation, After the meeting, and one Save" do
    @part.update!(counsel: "Good eye contact.")
    sign_in identities(:head)

    travel_to @part.meeting_on - 16 do
      get household_meeting_part_path(household_id: @home, id: @part)
    end

    assert_response :success
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", household_meeting_parts_path(household_id: @home), text: "Meeting parts"
    assert_select "h1", /Starting a Conversation/
    assert_select "h1 .Label", "Private"
    assert_select "main", text: /#{@part.meeting_on.strftime("%A, %B %-d")} · Midweek meeting · in 16 days/
    assert_select "a[href=?][data-turbo-frame=meeting_part_dialog]", edit_household_meeting_part_path(household_id: @home, id: @part), text: "Edit"
    assert_select "section[aria-labelledby=the-part]" do
      assert_select "*", text: /3 minutes/
      assert_select "*", text: /House to house/
      assert_select "*", text: /lmd lesson 1 point 3/
      assert_select "*", text: /Ana Ortiz/
      assert_select "a[href=?]", @part.program_url, text: "This week's program on wol.jw.org"
      assert_select "form[action=?]", household_meeting_notes_path(household_id: @home) do
        assert_select "input[name='meeting_note[kind]'][value=midweek]", count: 1
        assert_select "input[name='meeting_note[week_of]'][value=?]", @part.week_of.iso8601
        assert_select "button", "My notes for this meeting"
      end
    end
    assert_select "form[action=?]", household_meeting_part_path(household_id: @home, id: @part) do
      assert_select "lexxy-editor[name='meeting_part[preparation]']"
      assert_select "textarea[name='meeting_part[counsel]']", "Good eye contact."
      assert_select "*", text: /Only you see this, even when the part is shared./
      assert_select "button[type=submit]", "Save"
    end
    assert_select "dialog#delete-meeting-part form[action=?]", household_meeting_part_path(household_id: @home, id: @part)
  end

  test "edit is the dialog with the part's details" do
    sign_in identities(:head)

    get edit_household_meeting_part_path(household_id: @home, id: @part)

    assert_select "turbo-frame#meeting_part_dialog dialog[open]" do
      assert_select "*", text: /Edit part/
      assert_select "select[name='meeting_part[kind]'] option[selected]", "Starting a Conversation"
      assert_select "input[name='meeting_part[assistant]'][value='Ana Ortiz']"
    end
  end

  test "update saves the details from the dialog" do
    sign_in identities(:head)

    patch household_meeting_part_path(household_id: @home, id: @part), params: { meeting_part: part_params(setting: "") }, as: :turbo_stream

    assert_turbo_stream action: :refresh
    assert_equal [ "following_up", 4, nil ], @part.reload.then { [ it.kind, it.minutes, it.setting ] }
    assert_equal "Part saved.", flash[:notice]
  end

  test "update saves the preparation, with its references linked, and the counsel together" do
    sign_in identities(:head)

    patch household_meeting_part_path(household_id: @home, id: @part),
          params: { meeting_part: { preparation: "<p>Read Psalm 37:10, 11.</p>", counsel: "Warmer close next time." } }

    assert_redirected_to household_meeting_part_path(household_id: @home, id: @part)
    @part.reload
    assert_equal [ Bible::Reference.find("19:37:10-11") ], @part.preparation.body.attachables
    assert_equal "Warmer close next time.", @part.counsel
  end

  test "a refused update is :unprocessable_content and changes nothing" do
    sign_in identities(:head)

    patch household_meeting_part_path(household_id: @home, id: @part), params: { meeting_part: { counsel: "x" * 2001 } }

    assert_response :unprocessable_content
    assert_select "textarea[name='meeting_part[counsel]'][aria-invalid=true]"
    assert_nil @part.reload.counsel
  end

  test "a refused edit shows the dialog again with :unprocessable_content" do
    sign_in identities(:head)

    patch household_meeting_part_path(household_id: @home, id: @part), params: { meeting_part: part_params(kind: "bible_reading") }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-frame#meeting_part_dialog dialog[open] select[name='meeting_part[kind]'][aria-invalid=true]"
    assert_equal "starting_a_conversation", @part.reload.kind
  end

  test "destroy deletes the part and goes back to the list" do
    sign_in identities(:head)

    assert_difference -> { MeetingPart.count }, -1 do
      delete household_meeting_part_path(household_id: @home, id: @part)
    end

    assert_redirected_to household_meeting_parts_path(household_id: @home)
    assert_equal "Part deleted.", flash[:notice]
  end

  test "another person's part is a 404 for show, edit, update and destroy" do
    [
      -> { get household_meeting_part_path(household_id: @home, id: @part) },
      -> { get edit_household_meeting_part_path(household_id: @home, id: @part) },
      -> { patch household_meeting_part_path(household_id: @home, id: @part), params: { meeting_part: { counsel: "Mine now" } } },
      -> { delete household_meeting_part_path(household_id: @home, id: @part) }
    ].each do |request|
      sign_in identities(:spouse) # a 404 doesn't keep the session
      request.call
      assert_response :not_found
    end

    assert MeetingPart.exists?(@part.id)
    assert_nil @part.reload.counsel
  end

  test "a non-member gets a 404 for the household's list" do
    sign_in identities(:outsider)

    get household_meeting_parts_path(household_id: @home)

    assert_response :not_found
  end

  test "a child can add and edit their own" do
    sign_in identities(:eli)

    get household_meeting_parts_path(household_id: @home)
    assert_select "section[aria-labelledby=coming-up] li", text: /real friend/, count: 1

    assert_difference -> { users(:eli).meeting_parts.count } do
      post household_meeting_parts_path(household_id: @home), params: { meeting_part: part_params }
    end

    part = meeting_parts(:eli_conversation)
    patch household_meeting_part_path(household_id: @home, id: part), params: { meeting_part: { preparation: "<p>Read Proverbs 17:17</p>", counsel: "Nice smile" } }
    assert_redirected_to household_meeting_part_path(household_id: @home, id: part)
    assert_equal "Nice smile", part.reload.counsel
    assert_equal [ Bible::Reference.find("20:17:17") ], part.preparation.body.attachables
  end
end
