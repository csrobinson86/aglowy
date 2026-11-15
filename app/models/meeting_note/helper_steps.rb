# The meeting helper's steps for a kind of meeting, one prompt at a time, defined in code like the Outline
# (docs/design/meeting-helper.md, The helper's steps). Songs and prayers are steps but not outline parts,
# and Field Ministry is one step however many parts the program has.
class MeetingNote::HelperSteps
  include Enumerable

  # Each tone is a meeting-note section dot, as a Primer functional colour (fgColor-*).
  TONE_COLORS = { "song" => :accent, "treasures" => :muted, "ministry" => :attention, "weekend" => :attention, "living" => :danger }.freeze

  Step = Data.define(:key, :title, :short_title, :prompt, :draw_prompt, :mark_label, :marked_label, :icon, :tone, :talk_question) do
    def color
      TONE_COLORS.fetch(tone)
    end
  end

  OPENING_SONG = Step.new(key: "opening_song", title: "Song and prayer", short_title: "Song and prayer",
    prompt: "Sing along with everyone.", draw_prompt: "Draw something you sang about.",
    mark_label: "We sang!", marked_label: "Sang it", icon: "music", tone: "song",
    talk_question: "What was the first song about?")

  CLOSING_SONG = Step.new(key: "closing_song", title: "Song and prayer", short_title: "Last song",
    prompt: "Sing the last song together.", draw_prompt: "Draw something you sang about.",
    mark_label: "We sang!", marked_label: "Sang it", icon: "music", tone: "song",
    talk_question: "What was the last song about?")

  STEPS = {
    "midweek" => [
      OPENING_SONG,
      Step.new(key: "talk", title: "Treasures From God's Word", short_title: "Treasures",
        prompt: "Listen for someone from the Bible.", draw_prompt: "Draw who you heard about.",
        mark_label: "I heard it!", marked_label: "Heard it", icon: "ear", tone: "treasures",
        talk_question: "Who from the Bible did you hear about?"),
      Step.new(key: "spiritual_gems", title: "Spiritual Gems", short_title: "Spiritual gems",
        prompt: "Listen for something kind Jehovah did.", draw_prompt: "Draw what Jehovah did.",
        mark_label: "I heard it!", marked_label: "Heard it", icon: "gem", tone: "treasures",
        talk_question: "What kind thing did Jehovah do?"),
      Step.new(key: "bible_reading", title: "Bible Reading", short_title: "Bible reading",
        prompt: "Listen for the name of a Bible book.", draw_prompt: "Draw something from the reading.",
        mark_label: "I heard it!", marked_label: "Heard it", icon: "book", tone: "treasures",
        talk_question: "Which Bible book did you hear?"),
      Step.new(key: "field_ministry", title: "Apply Yourself to the Field Ministry", short_title: "Field ministry",
        prompt: "Watch the people talk. What did they share?", draw_prompt: "Draw what they shared.",
        mark_label: "I watched!", marked_label: "Watched it", icon: "people", tone: "ministry",
        talk_question: "What did the people at the door talk about?"),
      Step.new(key: "living", title: "Living as Christians", short_title: "Living as Christians",
        prompt: "What should we do this week?", draw_prompt: "Draw what we can do this week.",
        mark_label: "I heard it!", marked_label: "Heard it", icon: "house", tone: "living",
        talk_question: "What should we do this week?"),
      Step.new(key: "congregation_bible_study", title: "Congregation Bible Study", short_title: "Bible study",
        prompt: "Look at the pictures. Which one do you like?", draw_prompt: "Draw the picture you liked.",
        mark_label: "I watched!", marked_label: "Watched it", icon: "picture", tone: "living",
        talk_question: "Which picture did you like?"),
      CLOSING_SONG
    ],
    "weekend" => [
      OPENING_SONG,
      Step.new(key: "public_talk", title: "Public Talk", short_title: "Public talk",
        prompt: "Listen for a story from the Bible.", draw_prompt: "Draw the story you heard.",
        mark_label: "I heard it!", marked_label: "Heard it", icon: "ear", tone: "weekend",
        talk_question: "Which Bible story did you hear?"),
      Step.new(key: "watchtower_study", title: "Watchtower Study", short_title: "Watchtower",
        prompt: "Look at the pictures. Raise your hand if you know an answer.", draw_prompt: "Draw a picture from the study.",
        mark_label: "I watched!", marked_label: "Watched it", icon: "hand", tone: "weekend",
        talk_question: "Which picture did you like?"),
      CLOSING_SONG
    ]
  }.freeze

  def self.for(kind)
    new(STEPS.fetch(kind))
  end

  delegate :each, :size, :first, :last, to: :@steps

  def initialize(steps)
    @steps = steps
  end

  # A key that isn't one of this kind's steps is a 404, never a 500 (Trap 2).
  def fetch(key)
    find { it.key == key } or raise ActiveRecord::RecordNotFound, "No helper step #{key.inspect}"
  end

  # 1 for the first step.
  def position(step)
    @steps.index(step) + 1
  end

  def previous(step)
    @steps[position(step) - 2] unless step == first
  end

  def next(step)
    @steps[position(step)]
  end
end
