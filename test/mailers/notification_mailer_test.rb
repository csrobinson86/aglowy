require "test_helper"

# docs/design/notifications.md, Emails and Guardrails; frames email-weekly-preview.png and email-daily-summary.png.
class NotificationMailerTest < ActionMailer::TestCase
  setup do
    @home = households(:home)
    @home.update!(name: "Rivera household", time_zone: "Central Time (US & Canada)")
    @home.family_studies.destroy_all
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @head = users(:head)
    travel_to Time.utc(2026, 11, 22, 12)
    @session = @home.schedule_family_study(frequency: "once", starts_on: Date.new(2026, 11, 24), time_of_day: "19:00", topic: "Proverbs 4",
                                           notes: "<p>Private study notes</p>").first_session
    @home.events.create!(kind: "circuit_assembly", title: "Circuit assembly", starts_on: Date.new(2026, 11, 28), location: "Assembly Hall", created_by: @head)
  end

  test "the weekly preview: subject, the days with something on them, and the calendar link" do
    notification = @head.notify(kind: "weekly_preview", household: @home, subject: @home, data: { week_of: "2026-11-23" }, dedupe_key: "weekly_preview:1")

    email = NotificationMailer.notification(notification)

    assert_equal [ "head@example.com" ], email.to
    assert_equal [ "hello@localhost" ], email.from
    assert_equal "Your week in Rivera household: November 23 – 29", email.subject

    each_part(email) do |body|
      assert_includes body, "Your week in Rivera household"
      assert_includes body, "Monday, November 23 to Sunday, November 29."
      assert_match(/Tuesday.*Family study, 7:00 PM.*Proverbs 4.*Thursday.*Midweek meeting, 7:00 PM.*Saturday.*Circuit assembly, all day.*Assembly Hall.*Sunday.*Weekend meeting, 10:00 AM/m, body)
      assert_not_includes body, "Monday\n", "a day with nothing on it isn't listed"
      assert_includes body, "Open the calendar"
      assert_includes body, "http://example.com/#{@home.id}/notifications/#{notification.id}"
      assert_includes body, "You get this because you turned on Weekly preview emails."
    end
    assert_unsubscribes email, "weekly_preview"
  end

  test "a week that crosses into the next month names both months in the subject" do
    notification = @head.notify(kind: "weekly_preview", household: @home, subject: @home, data: { week_of: "2026-11-30" }, dedupe_key: "weekly_preview:2")

    assert_equal "Your week in Rivera household: November 30 – December 6", NotificationMailer.notification(notification).subject
  end

  test "the topic nudge: subject, which session, and its link" do
    session = @home.schedule_family_study(frequency: "once", starts_on: Date.new(2026, 11, 25), time_of_day: "19:00").first_session
    notification = @head.notify(kind: "study_topic_needed", household: @home, subject: session, dedupe_key: "study_topic_needed:#{session.id}")

    email = NotificationMailer.notification(notification)

    assert_equal [ "head@example.com" ], email.to
    assert_equal "Wednesday's family study needs a topic", email.subject
    each_part(email) do |body|
      assert_includes CGI.unescapeHTML(body), "Wednesday's family study has no topic yet"
      assert_includes body, "Choose a topic, or draft one with AI, before Wednesday, November 25."
      assert_includes body, "Rivera household"
      assert_includes body, "Choose a topic"
      assert_includes body, "http://example.com/#{@home.id}/notifications/#{notification.id}"
      assert_includes body, "You get this because you turned on Family study needs a topic emails."
    end
    assert_unsubscribes email, "study_topic_needed"
  end

  test "the daily summary: subject, a row per notification with its household, and the inbox link" do
    notifications = summary_notifications

    email = NotificationMailer.daily_summary(@head, notifications)

    assert_equal [ "head@example.com" ], email.to
    assert_equal "Your Aglowy summary: 2 new", email.subject
    each_part(email) do |body|
      assert_includes body, "Since yesterday"
      assert_includes body, "Things that waited for your daily summary."
      assert_match(/Rivera household.*Sam shared a meeting note.*Life and Ministry · week of November 16.*Rivera household.*Your invitation hasn(&#39;|')t been accepted.*grandpa@example.com was invited/m, body)
      assert_includes body, "Open notifications"
      assert_includes body, "http://example.com/#{@home.id}/notifications"
      assert_includes body, "You get this because you turned on emails for these notifications."
    end
    assert_unsubscribes email, "summary"
  end

  test "no note or study text" do
    preview = @head.notify(kind: "weekly_preview", household: @home, subject: @home, data: { week_of: "2026-11-23" }, dedupe_key: "weekly_preview:1")
    topic = @head.notify(kind: "study_topic_needed", household: @home, subject: @session, dedupe_key: "study_topic_needed:1")

    [ NotificationMailer.notification(preview), NotificationMailer.notification(topic), NotificationMailer.daily_summary(@head, summary_notifications) ].each do |email|
      each_part(email) do |body|
        assert_not_includes body, "Private study notes"
        assert_not_includes body, "Private meeting note text"
        assert_not_includes body, "Private talk title"
      end
    end
  end

  test "links carry no tracking parameters, and there are no images" do
    preview = @head.notify(kind: "weekly_preview", household: @home, subject: @home, data: { week_of: "2026-11-23" }, dedupe_key: "weekly_preview:1")

    [ NotificationMailer.notification(preview), NotificationMailer.daily_summary(@head, summary_notifications) ].each do |email|
      links = Nokogiri::HTML5(email.html_part.decoded).css("a").map { URI(it["href"]) } + URI.extract(email.text_part.decoded, %w[ http https ]).map { URI(it) }

      assert_operator links.size, :>=, 6
      links.each do |link|
        assert_equal "example.com", link.host, "every link goes straight to Aglowy, never through a redirect"
        assert_nil link.query, "#{link} carries parameters"
      end
      assert_empty Nokogiri::HTML5(email.html_part.decoded).css("img"), "no tracking pixel, or any other image"
    end
  end

  private
    def summary_notifications
      invitation = @home.invitations.create!(email: "grandpa@example.com", invited_by: @head)
      note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
      note.parts.first.update!(title: "Private talk title", notes: "<p>Private meeting note text</p>")
      [ @head.notify(kind: "shared_with_you", household: @home, subject: note, actor: users(:spouse), dedupe_key: "shared_with_you:1"),
        @head.notify(kind: "invitation_unaccepted", household: @home, subject: invitation, dedupe_key: "invitation_unaccepted:1") ]
    end

    def each_part(email)
      assert_equal %w[ text/plain text/html ], email.parts.map(&:mime_type)
      email.parts.each { yield it.decoded }
    end

    # RFC 8058 one-click: both headers, pointing at the scope's own signed link, the same one the footer shows.
    def assert_unsubscribes(email, scope)
      url = email["List-Unsubscribe"].value[/\A<(.+)>\z/, 1]
      token = url[%r{\Ahttp://example\.com/unsubscribe/#{scope}/(.+)\z}, 1]

      assert_equal @head, User.find_by_unsubscribe_token(scope, token)
      assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
      each_part(email) do |body|
        assert_includes body, url
        assert_includes body, "Turn off this email"
        assert_includes body, "Notification settings"
        assert_includes body, "http://example.com/#{@home.id}/settings/notifications"
      end
    end
end
