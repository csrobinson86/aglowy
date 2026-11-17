require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "squishes the name" do
    assert_equal "Ann Lee", User.new(name: "  Ann   Lee ").name
  end

  test "first_name is the first word of the name" do
    assert_equal "Hannah", users(:head).first_name
    assert_equal "Cher", User.new(name: "Cher").first_name
  end

  test "requires a name" do
    user = User.new(name: " ")

    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "time_zone is a known zone or unset" do
    assert User.new(name: "Ann", time_zone: "Central Time (US & Canada)").valid?
    assert_nil User.new(name: "Ann", time_zone: "").time_zone

    user = User.new(name: "Ann", time_zone: "Atlantis")
    assert_not user.valid?
    assert_includes user.errors[:time_zone], "is not included in the list"
  end

  test "a new user's appearance is auto" do
    assert_equal "auto", User.new(name: "Ann").appearance
    assert_equal "auto", User.create!(name: "Ann").reload.appearance
  end

  test "appearance sepia is invalid" do
    user = User.new(name: "Ann", appearance: "sepia")

    assert_not user.valid?
    assert_includes user.errors[:appearance], "is not included in the list"
  end

  test "active_household finds one of the person's active households by id, and nothing else" do
    assert_equal households(:home), users(:head).active_household(households(:home).id)
    assert_nil users(:former).active_household(households(:home).id)
    assert_nil users(:head).active_household(households(:other).id)
    assert_nil users(:head).active_household("not-a-uuid")
    assert_nil users(:head).active_household(nil)
  end

  test "active_households excludes households where the membership is inactive" do
    assert_equal [ households(:home), households(:parents) ].sort_by(&:id), users(:head).active_households.sort_by(&:id)
    assert_empty users(:former).active_households
  end

  # users(:head) is Maria in the frames; users(:eli) is Eli, a child in one household.
  test "can_start_household? is true for Maria" do
    assert users(:head).can_start_household?
  end

  test "can_start_household? is false for Eli" do
    assert_not users(:eli).can_start_household?
  end

  test "can_start_household? is true for someone who's a child in one household and an adult in another" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :adult)

    assert users(:eli).can_start_household?
  end

  test "can_start_household? is true for an adult whose only membership is inactive" do
    assert_equal [ [ "adult", false ] ], users(:former).memberships.map { [ it.role, it.active ] }

    assert users(:former).can_start_household?
  end

  test "can_start_household? is false for a child whose only membership is inactive" do
    memberships(:eli_in_home).update!(active: false)

    assert_not users(:eli).can_start_household?
  end

  test "can_start_household? is true for someone with no memberships yet" do
    assert_empty users(:newcomer).memberships

    assert users(:newcomer).can_start_household?
  end

  test "give_login makes a confirmed username-only login whose password nobody knows" do
    identity = users(:sofia).give_login(username: "Sofia.Rivera")

    assert identity.persisted?
    assert_equal "sofia.rivera", identity.username
    assert_nil identity.email
    assert identity.confirmed?
    assert identity.encrypted_password.present?
    assert_not identity.valid_password?("")
  end

  test "give_login with a taken username returns the unsaved login with the error" do
    identity = users(:sofia).give_login(username: "eli.rivera")

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "has already been taken"
  end

  # Two people choosing one username at once both pass the uniqueness check in Ruby; the unique index stops the second.
  test "give_login that loses the race for a username returns the unsaved login with the error, not an exception" do
    uniqueness = Identity.validators_on(:username).grep(ActiveRecord::Validations::UniquenessValidator).sole
    uniqueness.define_singleton_method(:validate) { |_record| }

    identity = assert_no_difference(-> { Identity.count }) { users(:sofia).give_login(username: "eli.rivera") }

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "has already been taken"
  ensure
    uniqueness.singleton_class.remove_method(:validate)
  end

  # Two submissions of the form at once both pass give_login? before either saves; identities.user_id stops the second.
  test "give_login for someone who got a login a moment ago returns the unsaved login with the error, not an exception" do
    identity = assert_no_difference(-> { Identity.count }) { users(:eli).give_login(username: "eli.second") }

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "wasn't saved: Eli already has a login"
  end

  test "database: a user without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      User.insert!({ name: nil })
    end
  end

  test "database: an appearance other than auto, light or dark raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      users(:head).update_column(:appearance, "sepia")
    end
  end

  test "accepted_ai_terms? is false with no acceptance" do
    assert_not users(:head).accepted_ai_terms?
  end

  test "accepted_ai_terms? is false with only an older version accepted" do
    Ai::Acceptance.create!(user: users(:head), version: Rails.configuration.x.ai.terms_version - 1, understood: "1")

    assert_not users(:head).accepted_ai_terms?
  end

  test "accepted_ai_terms? is true at the current version" do
    Ai::Acceptance.create!(user: users(:head), version: Rails.configuration.x.ai.terms_version, understood: "1")

    assert_predicate users(:head), :accepted_ai_terms?
  end

  test "may_ask_study_ai? for a child with a grant in one of two households" do
    Membership.create!(household: households(:parents), user: users(:eli), role: :child)
    assert_not users(:eli).may_ask_study_ai?

    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert users(:eli).reload.may_ask_study_ai?
  end

  test "personal_study_read_by_heads? while any of their child seats has a grant" do
    assert_not users(:eli).personal_study_read_by_heads?

    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert users(:eli).personal_study_read_by_heads?
    assert_not users(:head).personal_study_read_by_heads?
  end

  # Bookmarks (docs/design/bookmarks.md, User). The study's sources are what Aglowy showed the person.
  ARTICLE = { "url" => "https://www.jw.org/en/library/books/bible-questions-answered/", "title" => "Bible Questions Answered" }.freeze

  def study_with_article
    personal_studies(:head_suffering).tap do |study|
      personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "One." ] }, sources: [ ARTICLE ])
    end
  end

  test "bookmark takes the title from the study's sources" do
    bookmark = users(:head).bookmark(url: "#{ARTICLE["url"]}#top", source: study_with_article)

    assert bookmark.persisted?
    assert_equal ARTICLE["url"], bookmark.url
    assert_equal "Bible Questions Answered", bookmark.title
    assert_equal personal_studies(:head_suffering), bookmark.source
  end

  test "bookmark refuses a URL that isn't in the study's sources" do
    study = study_with_article

    assert_no_difference -> { Bookmark.count } do
      bookmark = users(:head).bookmark(url: "https://www.jw.org/en/whats-new/", source: study)

      assert_not bookmark.persisted?
      assert_includes bookmark.errors[:url], "isn't one of the pages in this study"
    end
  end

  test "bookmarking a saved page again finds the first bookmark" do
    study = study_with_article
    first = users(:head).bookmark(url: ARTICLE["url"], source: study)

    assert_no_difference -> { Bookmark.count } do
      assert_equal first, users(:head).bookmark(url: "#{ARTICLE["url"]}?utm_source=x", source: study)
    end
  end

  test "bookmark cuts a long title to 120 characters" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "One." ] }, sources: [ ARTICLE.merge("title" => "x" * 200) ])

    assert_equal 120, users(:head).bookmark(url: ARTICLE["url"], source: study).title.size
  end

  test "bookmark_for finds the person's own bookmark for a page or a scripture" do
    scripture = users(:head).bookmarks.create!(scripture: "19:23:4")
    page = bookmarks(:head_suffering_article)

    assert_equal page, users(:head).bookmark_for(url: "#{page.url}#top")
    assert_equal scripture, users(:head).bookmark_for(scripture: "19:23:4")
    assert_nil users(:spouse).bookmark_for(url: page.url)
    assert_nil users(:head).bookmark_for(url: "https://example.com/")
    assert_nil users(:head).bookmark_for
  end

  test "bookmarked holds the saved URLs in one query" do
    users(:head).bookmarks.create!(scripture: "19:23:4")
    page = bookmarks(:head_suffering_article)

    bookmarked = assert_queries_count(1) { users(:head).bookmarked }

    assert bookmarked.include?(page.url)
    assert bookmarked.include?("19:23:4")
    assert_not bookmarked.include?(bookmarks(:spouse_ransom_article).url)
    assert_equal page.id, bookmarked[page.url]
  end

  test "deleting a person deletes their bookmarks" do
    user = User.create!(name: "Ann")
    user.bookmarks.create!(url: ARTICLE["url"])

    assert_difference -> { Bookmark.count }, -1 do
      user.destroy!
    end
  end
end
