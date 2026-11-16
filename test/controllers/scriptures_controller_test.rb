require "test_helper"

class ScripturesControllerTest < ActionDispatch::IntegrationTest
  test "19:37:8-9 returns the sgid, the html and Psalm 37:8, 9" do
    sign_in identities(:head)

    get scripture_path("19:37:8-9")

    assert_response :success
    assert_equal "application/json", response.media_type
    json = response.parsed_body
    psalm = Bible::Reference.find("19:37:8-9")
    assert_equal psalm, ActionText::Attachable.from_attachable_sgid(json["sgid"])
    assert_equal "Psalm 37:8, 9", json["text"]
    html = Nokogiri::HTML5.fragment(json["html"])
    assert_equal "Psalm 37:8, 9", html.at("span.scripture-link").text.strip
    assert_nil html.at("a"), "the editor's copy isn't clickable"
  end

  test "19:151 is 404" do
    sign_in identities(:head)

    get scripture_path("19:151")

    assert_response :not_found
  end

  test "a signed-out request is redirected to sign in" do
    get scripture_path("19:37:8-9")

    assert_redirected_to new_identity_session_path
  end
end
