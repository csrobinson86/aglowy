require "test_helper"

class MeetingNote::HelperStepsTest < ActiveSupport::TestCase
  test "midweek has its 8 keys in order" do
    assert_equal %w[ opening_song talk spiritual_gems bible_reading field_ministry living congregation_bible_study closing_song ],
                 MeetingNote::HelperSteps.for("midweek").map(&:key)
  end

  test "weekend has its 4 keys in order" do
    assert_equal %w[ opening_song public_talk watchtower_study closing_song ], MeetingNote::HelperSteps.for("weekend").map(&:key)
  end

  test "an unknown key raises RecordNotFound" do
    assert_raises(ActiveRecord::RecordNotFound) { MeetingNote::HelperSteps.for("midweek").fetch("public_talk") }
    assert_raises(ActiveRecord::RecordNotFound) { MeetingNote::HelperSteps.for("weekend").fetch("nope") }
  end

  test "fetch finds a step with every field from the design doc" do
    step = MeetingNote::HelperSteps.for("weekend").fetch("watchtower_study")

    assert_equal "Watchtower Study", step.title
    assert_equal "Look at the pictures. Raise your hand if you know an answer.", step.prompt
    assert_equal "Draw a picture from the study.", step.draw_prompt
    assert_equal "I watched!", step.mark_label
    assert_equal "Watched it", step.marked_label
    assert_equal "hand", step.icon
    assert_equal "weekend", step.tone
    assert_equal :attention, step.color
    assert_equal "Which picture did you like?", step.talk_question
  end

  test "each tone has its meeting-note section colour" do
    colors = MeetingNote::HelperSteps.for("midweek").to_h { [ it.tone, it.color ] }

    assert_equal({ "song" => :accent, "treasures" => :muted, "ministry" => :attention, "living" => :danger }, colors)
  end

  test "every step's icon has its SVG" do
    (MeetingNote::HelperSteps.for("midweek").to_a + MeetingNote::HelperSteps.for("weekend").to_a).each do |step|
      assert Rails.root.join("app/assets/images/meeting_helper/#{step.icon}.svg").exist?, "no icon for #{step.key}"
    end
  end

  test "position, previous and next walk the steps in order" do
    steps = MeetingNote::HelperSteps.for("weekend")
    first, second, *, last = steps.to_a

    assert_equal 1, steps.position(first)
    assert_equal 4, steps.size
    assert_nil steps.previous(first)
    assert_equal first, steps.previous(second)
    assert_equal second, steps.next(first)
    assert_nil steps.next(last)
  end

  test "a note's helper_steps are its kind's" do
    assert_equal MeetingNote::HelperSteps.for("weekend").map(&:key), meeting_notes(:head_weekend).helper_steps.map(&:key)
  end
end
