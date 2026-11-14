require "test_helper"

class FamilyStudiesHelperTest < ActionView::TestCase
  test "session_time_range shows the meridiem once when both ends share it" do
    assert_equal "7:00 – 7:45 PM", session_time_range(family_study_sessions(:weekly_next))
  end

  test "session_time_range shows both meridiems when the session crosses noon" do
    study_session = family_study_sessions(:weekly_next)
    study_session.scheduled_at = study_session.scheduled_at.change(hour: 11, min: 30)

    assert_equal "11:30 AM – 12:15 PM", session_time_range(study_session)
  end

  test "session_time_range is in the household's zone" do
    households(:home).update!(time_zone: "Tokyo")

    assert_equal "4:00 – 4:45 AM", session_time_range(family_study_sessions(:weekly_next))
  end
end
