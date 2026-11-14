require "test_helper"

class FamilyStudy::ResourceTest < ActiveSupport::TestCase
  setup do
    @session = family_study_sessions(:weekly_next)
  end

  test "javascript: is refused" do
    resource = @session.resources.new(url: "javascript:alert(1)")

    assert_not resource.valid?
    assert_equal [ "must be a web address starting with http:// or https://" ], resource.errors[:url]
  end

  test "ftp: is refused" do
    assert_not @session.resources.new(url: "ftp://files.example.com/proverbs.pdf").valid?
  end

  test "a scheme that only starts with http is refused" do
    assert_not @session.resources.new(url: "https-evil:alert(1)").valid?
    assert_not @session.resources.new(url: "http:no-host").valid?
  end

  test "a URL that doesn't parse is refused" do
    assert_not @session.resources.new(url: "http://www.jw.org:port/").valid?
    assert_not @session.resources.new(url: "").valid?
  end

  test "http and https are accepted" do
    assert @session.resources.new(url: "http://www.jw.org/en/").valid?
    assert @session.resources.new(url: "https://wol.jw.org/en/wol/h/r1/lp-e").valid?
    assert @session.resources.new(url: "HTTPS://www.jw.org/").valid?
  end

  test "a jw.org link in another language is accepted, encoded, with a readable title" do
    resource = @session.resources.create!(url: "https://wol.jw.org/es/wol/d/r4/lp-s/año|1")

    assert_equal "https://wol.jw.org/es/wol/d/r4/lp-s/a%C3%B1o%7C1", resource.url
    assert_equal "wol.jw.org/es/wol/d/r4/lp-s/año|1", resource.title
  end

  test "the URL is stripped of surrounding spaces" do
    assert_equal "https://www.jw.org/en/", @session.resources.new(url: "  https://www.jw.org/en/ ").url
  end

  test "title defaults from the URL: host and path" do
    resource = @session.resources.create!(url: "https://www.jw.org/en/library/books/draw-close/?q=1")

    assert_equal "www.jw.org/en/library/books/draw-close", resource.title
    assert_equal "www.jw.org", resource.host
  end

  test "title defaults to the host alone when there is no path" do
    assert_equal "www.jw.org", @session.resources.create!(url: "https://www.jw.org").title
  end

  test "a title given is kept" do
    assert_equal "Proverbs 3", @session.resources.create!(url: "https://www.jw.org/", title: "Proverbs 3").title
  end

  test "a link is the default kind" do
    assert_predicate @session.resources.new, :link?
  end

  test "each new resource goes after the session's last one" do
    study_session = family_study_sessions(:one_off_first)

    assert_equal 3, study_session.resources.create!(url: "https://www.jw.org/").position
    assert_equal 1, @session.resources.create!(url: "https://www.jw.org/").position
  end

  test "a session lists its resources in position order" do
    family_study_resources(:proverbs).update_column(:position, 5)

    assert_equal family_study_resources(:draw_close, :proverbs), family_study_sessions(:one_off_first).resources.to_a
  end

  test "removing a session removes its resources" do
    assert_difference -> { FamilyStudy::Resource.count }, -2 do
      family_study_sessions(:one_off_first).destroy!
    end
  end

  test "database: a kind other than link or file raises CheckViolation" do
    session = family_study_sessions(:one_off_first)

    assert_raises ActiveRecord::CheckViolation do
      FamilyStudy::Resource.insert!({ session_id: session.id, kind: "video", url: "https://www.jw.org/", title: "www.jw.org" })
    end
  end

  test "database: a link without a url raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { family_study_resources(:proverbs).update_column(:url, nil) }
  end

  test "database: a link that isn't http or https raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { family_study_resources(:proverbs).update_column(:url, "javascript:alert(1)") }
  end

  test "database: a resource without a kind raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_study_resources(:proverbs).update_column(:kind, nil) }
  end

  test "database: a resource without a title raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_study_resources(:proverbs).update_column(:title, nil) }
  end

  test "database: a resource for a missing session raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { family_study_resources(:proverbs).update_column(:session_id, SecureRandom.uuid_v7) }
  end
end
