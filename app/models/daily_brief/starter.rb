# The four plans Start offers, each with its focus areas and a week of rows (docs/design/daily-brief.md, Start; frame
# brief-start.png). Plan.start copies one; the person can change every part of it afterwards.
class DailyBrief::Starter
  # One weekday's row, with each topic keyed by the library key of the focus area it's for.
  Day = Data.define(:wday, :reading, :examples, :topics)

  # The reading, qualities and faith examples every starter's week shares, Monday first (frame brief-plan.png).
  WEEK = [
    [ 1, "Genesis – Esther", "Joy, Love, Integrity", "Noah, Joseph" ],
    [ 2, "Matthew – John", "Patience, Mildness", "Abraham, Moses" ],
    [ 3, "Acts", "Peace, Honesty, Long-suffering", "Peter, Paul" ],
    [ 4, "Isaiah – Malachi, Revelation", "Kindness, Humility, Courage", "Jeremiah, Isaiah" ],
    [ 5, "Job, Psalms, Song of Solomon", "Goodness, Forgiveness, Mercy", "Elijah, David, Samuel, Jonah" ],
    [ 6, "Proverbs, Ecclesiastes", "Self-control, Endurance", "Abigail, Esther, Ruth, Hannah" ],
    [ 0, "Romans – Jude", "Faith, Loyalty, Tact", "Timothy, modern-day examples" ]
  ].freeze

  attr_reader :key, :name

  def initialize(key, name:, focus_areas:, description: nil, topics: {})
    @key, @name, @focus_area_keys, @description, @topics = key, name, focus_areas, description, topics
  end

  ALL = [
    new("husband_and_father", name: "A husband and father", focus_areas: %w[ husband father reaching_out qualities appreciation ],
        topics: {
          "husband" => { 1 => "Love my wife as my own body", 3 => "No secrets; honest with my wife", 5 => "Making things right", 6 => "Faithfulness" },
          "father" => { 2 => "Patient teaching of my children", 4 => "Presiding over my household well", 0 => "Family worship" },
          "reaching_out" => { 1 => "A clean conscience (v. 9)", 2 => "Serious (v. 8)", 3 => "Not double-tongued (v. 8)", 4 => "Tested as to fitness (v. 10)",
                              5 => "Free from accusation (v. 10)", 6 => "Moderate in habits", 0 => "Self-sacrifice" }
        }),
    new("wife_and_mother", name: "A wife and mother", focus_areas: %w[ wife mother ministry qualities appreciation ]),
    new("on_my_own", name: "On my own", focus_areas: %w[ congregation ministry qualities appreciation ]),
    new("basics", name: "The basics", focus_areas: %w[ qualities ],
        description: "Daily text, a Bible reading, a quality and a faith example. Add focus areas later.")
  ].freeze

  def self.all = ALL
  def self.find(key) = ALL.find { it.key == key }

  def focus_areas
    @focus_area_keys.map { DailyBrief::FocusArea::Library.find(it) }
  end

  # What Start lists under its name: its focus areas, unless it says otherwise.
  def description
    @description || focus_areas.map(&:name).join(" · ")
  end

  def days
    WEEK.map do |wday, reading, qualities, examples|
      topics = @topics.transform_values { it[wday] }.merge("qualities" => qualities).compact
      Day.new(wday:, reading:, examples:, topics:)
    end
  end
end
