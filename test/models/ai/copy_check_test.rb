require "test_helper"

class Ai::CopyCheckTest < ActiveSupport::TestCase
  CITATIONS = [ { url: "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025", cited_text: [ "When a family prays together, each one learns to speak to Jehovah as a friend." ] } ].freeze

  test "removes a sentence sharing 8 consecutive words with a citation, despite case, punctuation and spacing" do
    fields, removed = clean("closing" => "Pray daily. We see A family prays together—each ONE   learns, to grow! Talk about it.")

    assert_equal({ "closing" => "Pray daily. Talk about it." }, fields)
    assert removed
  end

  test "keeps a sentence sharing 7" do
    closing = "We hope each one learns to speak to Jehovah daily."

    assert_equal [ { "closing" => closing }, false ], clean("closing" => closing)
  end

  test "removes a sentence quoting 6 words in straight quotes, and one in curly quotes" do
    fields, removed = clean(
      "opening" => { "question" => %(Jesus said "pray then in this way, Father." What did he mean?) },
      "points" => [ { "heading" => "Ask “do not be anxious over anything” together. Then pray." } ]
    )

    assert_equal({ "opening" => { "question" => "What did he mean?" }, "points" => [ { "heading" => "Then pray." } ] }, fields)
    assert removed
  end

  test "keeps a sentence quoting 5 words" do
    question = %(What does "keep on asking, and it" mean to us?)

    assert_equal [ { "question" => question }, false ], clean("question" => question)
  end

  test "keeps the scripture reference when a quoted verse is removed from the same field's other sentence" do
    fields, = clean("question" => "Read Philippians 4:6, 7 together. “Do not be anxious over anything, but in everything by prayer.”")

    assert_equal({ "question" => "Read Philippians 4:6, 7 together." }, fields)
  end

  test "reports when something was removed" do
    _, removed = clean("title" => "Talking to Jehovah", "off_topic" => false, "points" => [ { "question" => %(Who said "each one learns to speak to Jehovah"?) } ])
    _, nothing = clean("title" => "Talking to Jehovah", "off_topic" => false, "points" => [])

    assert removed
    assert_not nothing
  end

  test "removes a copied run that crosses a sentence break, and a quotation left open" do
    fields, = clean("closing" => "Kneel together. When a family prays together. Each one learns to speak. Sing.", "children" => 'Read "do not be anxious over anything at all')

    assert_equal({ "closing" => "Kneel together. Sing.", "children" => "" }, fields)
  end

  test "removes a sentence quoting 6 words in single quotes, not stopping at an apostrophe" do
    fields, = clean(
      "question" => "Jesus said ‘don’t be anxious over anything at all.’ Why? He said 'keep on asking, and it will be given.' Pray.",
      "closing" => "Let’s ‘talk to Jehovah’ and don't stop. It's the parents’ ‘time to pray.’"
    )

    assert_equal({ "question" => "Why? Pray.", "closing" => "Let’s ‘talk to Jehovah’ and don't stop. It's the parents’ ‘time to pray.’" }, fields)
  end

  test "removes a copied run that removing a sentence between its halves brings together" do
    fields, = clean("closing" => "When a family prays. Say “one two three four five six”. Together each one learns. Sing.")

    assert_equal({ "closing" => "Sing." }, fields)
  end

  test "keeps a sentence whose shortened year and possessive hold no quotation, but not a quotation opening with a number" do
    closing = "Remember the '90s when all of our dear parents' prayers helped us. In ‘05 our grandparents’ faith grew."
    fields, = clean("closing" => closing, "question" => "Read '1 Corinthians 13:4 love is patient and kind.' Then ‘144,000 will rule with Christ in heaven.’ Pray.")

    assert_equal({ "closing" => closing, "question" => "Pray." }, fields)
  end

  private
    def clean(fields)
      Ai::CopyCheck.clean(fields, citations: CITATIONS, overlap_words: 8, quote_max_words: 5)
    end
end
