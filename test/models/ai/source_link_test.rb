require "test_helper"

class Ai::SourceLinkTest < ActiveSupport::TestCase
  SEARCH_RESULTS = [
    { url: "https://www.jw.org/en/bible-teachings/family/family-worship/", title: "Family Worship", cited_text: [ "An excerpt from the page." ] },
    { url: "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025", title: "Praying Together as a Family", cited_text: [] }
  ].freeze

  test "keeps a www.jw.org and a wol.jw.org link that are in the search results" do
    assert_equal [
      { url: "https://www.jw.org/en/bible-teachings/family/family-worship/", title: "Family Worship" },
      { url: "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025", title: "Praying Together as a Family" }
    ], keep(SEARCH_RESULTS.pluck(:url))
  end

  test "drops a link on another host, over http, or with a user or a port" do
    results = [
      "https://jw.org.example.com/en/bible-teachings/family/family-worship/",
      "https://example.com/jw.org",
      "http://www.jw.org/en/bible-teachings/family/family-worship/",
      "https://user@www.jw.org/en/bible-teachings/family/family-worship/",
      "https://www.jw.org:8443/en/bible-teachings/family/family-worship/"
    ].map { { url: it, title: "Looks like Family Worship" } }

    assert_empty keep(results.pluck(:url), search_results: results)
  end

  test "drops a jw.org link that isn't in the search results" do
    assert_empty keep([ "https://www.jw.org/en/bible-teachings/questions/an-article-the-ai-made-up/" ])
  end

  test "removes duplicates that differ only in fragment or utm_ parameters" do
    links = keep([
      "https://www.jw.org/en/bible-teachings/family/family-worship/#p3",
      "https://www.jw.org/en/bible-teachings/family/family-worship/?utm_source=ai&utm_medium=chat",
      "https://www.jw.org/en/bible-teachings/family/family-worship/"
    ])

    assert_equal [ { url: "https://www.jw.org/en/bible-teachings/family/family-worship/", title: "Family Worship" } ], links
  end

  test "never returns cited_text" do
    links = keep(SEARCH_RESULTS)

    assert_equal [ %i[ url title ] ] * 2, links.map(&:keys)
  end

  test "makes no HTTP request" do
    Net::HTTP.stub(:start, ->(*) { raise "Aglowy never requests a jw.org page" }) do
      assert_equal 2, keep(SEARCH_RESULTS.pluck(:url)).size
    end
  end

  test "drops what isn't a URL at all" do
    assert_empty keep([ nil, "", "not a url", "https://www.jw.org/en/<script>", "javascript:alert(1)" ])
  end

  private
    def keep(candidates, search_results: SEARCH_RESULTS)
      Ai::SourceLink.keep(candidates, search_results: search_results, allowed_hosts: Ai::Purpose::ALLOWED_HOSTS)
    end
end
