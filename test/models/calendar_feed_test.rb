require "test_helper"

# A person's private subscribe link (docs/design/calendar.md, CalendarFeed): found by its token, which Reset replaces.
class CalendarFeedTest < ActiveSupport::TestCase
  setup do
    @feed = users(:head).ensure_calendar_feed
  end

  test "reset changes the token; the old token no longer finds it" do
    old_token = @feed.token

    @feed.reset

    assert_not_equal old_token, @feed.reload.token
    assert_nil CalendarFeed.find_by(token: old_token)
    assert_equal @feed, CalendarFeed.find_by(token: @feed.token)
  end

  test "the first view makes the link, and later views find the same one" do
    assert_equal @feed, users(:head).reload.ensure_calendar_feed
    assert_equal 1, CalendarFeed.where(user: users(:head)).count
  end

  test "the token isn't readable in the database" do
    stored = CalendarFeed.connection.select_value(CalendarFeed.where(id: @feed.id).select(:token).to_sql)

    assert_not_includes stored, @feed.token
  end

  test "the database refuses a second link for one person" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      CalendarFeed.insert!({ user_id: users(:head).id, token: "another-token-for-the-same-person" })
    end
  end

  test "the database refuses a token another link has" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      CalendarFeed.insert!({ user_id: users(:spouse).id, token: @feed.token })
    end
  end

  test "the database refuses a link without a token" do
    assert_raises(ActiveRecord::NotNullViolation) { @feed.update_column(:token, nil) }
  end
end
