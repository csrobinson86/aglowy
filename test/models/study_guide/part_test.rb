require "test_helper"

# A part of a study guide (docs/design/study-guide.md, StudyGuide::Part). Its content is encrypted JSON, so the
# database checks only the step and one part per step: the model checks the content against the step's shape.
class StudyGuide::PartTest < ActiveSupport::TestCase
  STEPS = %w[ midweek_overview talk spiritual_gems bible_reading field_ministry living congregation_bible_study
              weekend_overview watchtower_study ].freeze

  setup { @talk = study_guide_parts(:head_nov_9_talk) }

  test "database: an unknown step" do
    assert_raises(ActiveRecord::CheckViolation) { StudyGuide::Part.insert!(row(step: "public_talk")) }
  end

  test "database: a second part for a step in the same guide" do
    assert_raises(ActiveRecord::RecordNotUnique) { StudyGuide::Part.insert!(row(step: "talk")) }
  end

  test "database: a part needs its content" do
    assert_raises(ActiveRecord::NotNullViolation) { @talk.update_column(:content, nil) }
  end

  test "database: a part needs its guide" do
    assert_raises(ActiveRecord::NotNullViolation) { @talk.update_column(:study_guide_id, nil) }
  end

  test "content is stored encrypted and reads back as its fields" do
    @talk.reload

    assert @talk.encrypted_attribute?(:content)
    assert_not_includes @talk.ciphertext_for(:content), "Jerusalem"
    assert_equal({ "text" => "Jerusalem was warned many times before it fell.", "ref" => "Lamentations 1:18" }, @talk.content["points"].first)
  end

  test "the meeting comes from the step: the Watchtower Study and its overview are the weekend's" do
    assert_equal STEPS.map { it.in?(%w[ weekend_overview watchtower_study ]) ? "weekend" : "midweek" },
                 STEPS.map { StudyGuide::Part.new(step: it).meeting }
  end

  test "each step's least content is valid" do
    STEPS.each { assert part(it, valid_study_guide_content(it)).valid?, "#{it} wasn't valid" }
  end

  test "each step's full content from the design is valid" do
    guide = JSON.parse(JSON.parse(file_fixture("ai/study_guide.json").read)["content"].filter_map { it["text"] }.join)

    STEPS.each do |step|
      content = guide.fetch(step).transform_values { |value| value.is_a?(Array) ? value.map { it.compact_blank } : value }
      assert part(step, content).valid?, "#{step} wasn't valid"
    end
  end

  test "an unknown step or content that isn't fields is invalid" do
    assert_not part("public_talk", valid_study_guide_content("talk")).valid?
    assert_not part("talk", "A part to keep.").valid?
  end

  test "each step needs its own text: the overviews' glance, the Bible Reading's reading, the others' summary" do
    STEPS.each do |step|
      required = step.include?("overview") ? "glance" : "summary"
      assert_not part(step, valid_study_guide_content(step).except(required)).valid?, "#{step} was valid without its #{required}"
    end
    assert_not part("bible_reading", valid_study_guide_content("bible_reading").except("reading")).valid?
  end

  test "a field the step doesn't have is invalid" do
    assert_not part("living", valid_study_guide_content("living").merge("comments" => [ { "text" => "One." } ])).valid?
    assert_not part("talk", valid_study_guide_content("talk").merge("reading" => "Lamentations 1–2")).valid?
  end

  test "word limits: a summary of 50, a glance of 40, a title of 12 and an item of 30 words" do
    assert part("talk", content_with(summary: 50, title: 12, item: 30)).valid?
    assert part("midweek_overview", valid_study_guide_content("midweek_overview").merge("glance" => words(40))).valid?

    assert_not part("talk", content_with(summary: 51)).valid?
    assert_not part("talk", content_with(title: 13)).valid?
    assert_not part("talk", content_with(item: 31)).valid?
    assert_not part("midweek_overview", valid_study_guide_content("midweek_overview").merge("glance" => words(41))).valid?
    assert_not part("talk", valid_study_guide_content("talk").merge("summary" => " ")).valid?
  end

  test "list lengths: up to 4 points, 2 to 4 comment ideas for Spiritual Gems, and 1 to 4 qualities in an overview" do
    point = { "text" => "A point." }
    assert part("talk", valid_study_guide_content("talk").merge("points" => [ point ] * 4)).valid?
    assert_not part("talk", valid_study_guide_content("talk").merge("points" => [ point ] * 5)).valid?
    assert_not part("spiritual_gems", valid_study_guide_content("spiritual_gems").merge("comments" => [ point ])).valid?
    assert_not part("spiritual_gems", valid_study_guide_content("spiritual_gems").merge("comments" => [ point ] * 5)).valid?
    assert_not part("weekend_overview", valid_study_guide_content("weekend_overview").merge("jehovah" => [])).valid?
  end

  test "an item needs its text and its label, and a ref only if it parses" do
    assert_not part("talk", valid_study_guide_content("talk").merge("points" => [ { "ref" => "Psalm 23" } ])).valid?
    assert_not part("talk", valid_study_guide_content("talk").merge("points" => [ { "text" => "A point.", "ref" => "Psalm 151" } ])).valid?
    assert_not part("talk", valid_study_guide_content("talk").merge("points" => [ { "text" => "A point.", "paragraph" => "5" } ])).valid?
    assert_not part("midweek_overview", valid_study_guide_content("midweek_overview").merge("jehovah" => [ { "text" => "He cares." } ])).valid?
    assert_not part("watchtower_study", valid_study_guide_content("watchtower_study").merge("notes" => [ { "text" => "A note." } ])).valid?
    assert part("watchtower_study", valid_study_guide_content("watchtower_study").merge("notes" => [ { "paragraphs" => "4–7", "text" => "A note.", "ref" => "Psalm 23" } ])).valid?
  end

  private
    def part(step, content)
      StudyGuide::Part.new(study_guide: study_guides(:head_nov_9), step:, content:)
    end

    def words(count) = ([ "Jehovah" ] * count).join(" ")

    def content_with(summary: 1, title: 1, item: 1)
      { "title" => words(title), "summary" => words(summary), "points" => [ { "text" => words(item) } ] }
    end

    def row(step:)
      { study_guide_id: study_guides(:head_nov_9).id, step:, content: "{}", created_at: Time.current }
    end
end
