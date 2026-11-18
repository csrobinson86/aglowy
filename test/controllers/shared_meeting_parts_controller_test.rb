require "test_helper"

# The parts members have shared into this household (docs/design/meeting-parts.md, The list).
class SharedMeetingPartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
  end

  test "lists only this household's shared parts, coming up then earlier, with their owners' names" do
    meeting_parts(:spouse_talk).share_with(@home)
    meeting_parts(:head_disciples).share_with(@home)
    meeting_parts(:head_conversation).share_with(households(:parents)) # another household's
    sign_in identities(:eli)

    get household_shared_meeting_parts_path(household_id: @home)

    assert_response :success
    assert_select "title", "Shared in The Head Family · The Head Family · Aglowy"
    assert_select "h1", "Meeting parts"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Meeting parts"
    assert_select "ul[aria-label='Show'] a[href=?]", household_meeting_parts_path(household_id: @home), text: "Mine"
    assert_select "ul[aria-label='Show'] a[aria-current='true']", text: /Shared in The Head Family\s+2/
    assert_select "section[aria-labelledby=coming-up] li", count: 1 do |row|
      assert_select row, "a[href=?]", household_meeting_part_path(household_id: @home, id: meeting_parts(:spouse_talk)), text: "Talk"
      assert_select row, "*", text: /Sam Spouse · /
      assert_select row, "*", text: /Why we can trust the Bible/
    end
    assert_select "section[aria-labelledby=earlier] li", count: 1 do |row|
      assert_select row, "a", text: "Making Disciples"
      assert_select row, "*", text: /Hannah Head · /
    end
    assert_select "main", text: /hope for the future/, count: 0
    assert_select "main", text: /real friend/, count: 0
    assert_select "section li .Label", count: 0
  end

  test "another household's shared parts are absent, and an owner who left takes theirs" do
    meeting_parts(:head_conversation).share_with(households(:parents))
    meeting_parts(:spouse_talk).share_with(@home)
    memberships(:spouse_in_home).update_column(:active, false)
    sign_in identities(:head)

    get household_shared_meeting_parts_path(household_id: @home)

    assert_select "section li", count: 0
    assert_select ".blankslate", text: /Nothing shared yet/ do
      assert_select "*", text: /Parts members share with The Head Family will show here./
    end
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    get household_shared_meeting_parts_path(household_id: @home)

    assert_response :not_found
  end
end
