# The ready-made focus areas the focus area dialog offers, and the starters are made from (docs/design/daily-brief.md,
# DailyBrief::FocusArea). Picking one fills the form; the person can change every field. Every reference parses.
class DailyBrief::FocusArea::Library
  attr_reader :key, :kind, :name, :gives, :scriptures

  def initialize(key, kind:, name:, gives:, scriptures:)
    @key, @kind, @name, @gives, @scriptures = key, kind, name, gives, scriptures
  end

  ALL = [
    new("husband", kind: "role", name: "As a husband", gives: "One way to show love, honesty and loyalty to my wife today.",
        scriptures: "Ephesians 5:25; Ephesians 5:28; Proverbs 5:18"),
    new("father", kind: "role", name: "As a father", gives: "One way to teach, be patient with, or spend time with my children today.",
        scriptures: "Deuteronomy 6:6, 7; Ephesians 6:4"),
    new("wife", kind: "role", name: "As a wife", gives: "One way to show love, respect and support to my husband today.",
        scriptures: "Ephesians 5:33; Proverbs 31:11, 12"),
    new("mother", kind: "role", name: "As a mother", gives: "One way to teach, comfort, or spend time with my children today.",
        scriptures: "Proverbs 1:8; 2 Timothy 1:5"),
    new("reaching_out", kind: "role", name: "Reaching out", gives: "The day's qualification, and one action that shows reliability.",
        scriptures: "1 Timothy 3:8-13"),
    new("ministry", kind: "role", name: "In the ministry", gives: "One way to prepare for, or share in, the ministry today.",
        scriptures: "Matthew 28:19, 20; 2 Timothy 4:5"),
    new("congregation", kind: "role", name: "In the congregation", gives: "One way to encourage or help someone in the congregation today.",
        scriptures: "Hebrews 10:24, 25"),
    new("work", kind: "role", name: "At work", gives: "One way to show honesty and a good spirit at work today.",
        scriptures: "Colossians 3:23"),
    new("heart", kind: "role", name: "Guard your heart", gives: "One thing to watch for, and one way to keep my heart clean today.",
        scriptures: "Proverbs 4:23"),
    new("qualities", kind: "quality", name: "Qualities to focus on", gives: "What the quality is, how Jesus showed it, and one way to show it today.",
        scriptures: "Galatians 5:22, 23"),
    new("appreciation", kind: "appreciation", name: "Growing appreciation for Jehovah",
        gives: "One thing the day's reading shows about him, and a question to think over.", scriptures: "Psalm 145:3-7")
  ].freeze

  def self.all = ALL
  def self.find(key) = ALL.find { it.key == key }
end
