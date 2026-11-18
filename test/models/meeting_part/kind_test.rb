require "test_helper"

class MeetingPart::KindTest < ActiveSupport::TestCase
  test "the six kinds, in the workbook's order" do
    assert_equal %w[ starting_a_conversation following_up making_disciples explaining_beliefs_demonstration explaining_beliefs_talk talk ],
                 MeetingPart::Kind.all.map(&:key)
    assert_equal MeetingPart::Kind.all.map(&:key), MeetingPart::Kind.keys
  end

  test "their labels, with Demonstration or Talk as the detail for Explaining Your Beliefs" do
    labels = MeetingPart::Kind.all.to_h { [ it.key, [ it.label, it.detail ] ] }

    assert_equal({ "starting_a_conversation" => [ "Starting a Conversation", nil ],
                   "following_up" => [ "Following Up", nil ],
                   "making_disciples" => [ "Making Disciples", nil ],
                   "explaining_beliefs_demonstration" => [ "Explaining Your Beliefs", "Demonstration" ],
                   "explaining_beliefs_talk" => [ "Explaining Your Beliefs", "Talk" ],
                   "talk" => [ "Talk", nil ] }, labels)
  end

  test "the form's option names Explaining Your Beliefs twice, (demonstration) and (talk)" do
    assert_equal [ "Starting a Conversation", "Following Up", "Making Disciples", "Explaining Your Beliefs (demonstration)",
                   "Explaining Your Beliefs (talk)", "Talk" ], MeetingPart::Kind.all.map(&:option_label)
  end

  test "demonstration? and talk?" do
    demonstrations, talks = MeetingPart::Kind.all.partition(&:demonstration?)

    assert_equal %w[ starting_a_conversation following_up making_disciples explaining_beliefs_demonstration ], demonstrations.map(&:key)
    assert_equal %w[ explaining_beliefs_talk talk ], talks.map(&:key)
    assert talks.all?(&:talk?)
    assert_not demonstrations.any?(&:talk?)
  end

  test "other_speaker: who the person talks with, none for a talk" do
    speakers = MeetingPart::Kind.all.to_h { [ it.key, it.other_speaker ] }

    assert_equal({ "starting_a_conversation" => "Householder", "following_up" => "Householder", "making_disciples" => "Bible student",
                   "explaining_beliefs_demonstration" => "Other person", "explaining_beliefs_talk" => nil, "talk" => nil }, speakers)
  end

  test "find looks a kind up by its key, nil for anything else" do
    assert_equal "Following Up", MeetingPart::Kind.find("following_up").label
    assert_nil MeetingPart::Kind.find("bible_reading")
  end
end
