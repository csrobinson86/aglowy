require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "color_mode is the signed-in person's appearance" do
    users(:head).update!(appearance: "dark")
    Current.identity = identities(:head)

    assert_equal "dark", color_mode
  end

  test "color_mode is auto when signed out" do
    assert_equal "auto", color_mode
  end

  # No page renders the application layout today, so render it on its own.
  test "the application layout uses color_mode" do
    users(:head).update!(appearance: "dark")
    Current.identity = identities(:head)

    render template: "layouts/application"

    assert_select "body[data-color-mode=dark][data-light-theme=light][data-dark-theme=dark]"
  end
end
