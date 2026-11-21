require "test_helper"

class MeetingPrepsHelperTest < ActionView::TestCase
  test "every quality has its icon" do
    PrepWeek::Card::QUALITIES.each_key do |quality|
      assert_match "<svg", meeting_prep_quality_icon(PrepWeek::Card.new(quality:)), "for #{quality}"
    end
  end
end
