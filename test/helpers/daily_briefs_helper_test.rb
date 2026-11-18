require "test_helper"

class DailyBriefsHelperTest < ActionView::TestCase
  test "verses_label names one verse or several, and says look for when the reference names none" do
    assert_equal "Verse 22", verses_label("Matthew 16:22")
    assert_equal "Verses 21-23", verses_label("Matthew 16:21-23")
    assert_equal "Verses 8, 9", verses_label("Psalm 37:8, 9")
    assert_equal "Look for", verses_label("Matthew 16")
    assert_equal "Look for", verses_label("not a reference")
  end
end
