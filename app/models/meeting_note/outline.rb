# The shape of a meeting's notes, defined in code rather than the database. A note keeps the
# outline_version it was built with, so a new format gets a new version and old notes keep theirs.
# A section's dot is a Primer functional colour (the fgColor-* tokens).
class MeetingNote::Outline
  Section = Data.define(:name, :dot, :parts)

  Part = Data.define(:key, :label, :fields, :repeats) do
    def initialize(key:, label:, fields:, repeats: false)
      super
    end

    alias_method :repeats?, :repeats
  end

  VERSIONS = {
    # Life and Ministry checked against the meeting instructions, S-38 8/26.
    1 => {
      "midweek" => [
        Section.new(name: "Treasures From God's Word", dot: :muted, parts: [
          Part.new(key: "talk", label: "Talk", fields: %i[ title notes ]),
          Part.new(key: "spiritual_gems", label: "Spiritual Gems", fields: %i[ gems ]),
          Part.new(key: "bible_reading", label: "Bible Reading", fields: %i[ notes ])
        ]),
        Section.new(name: "Apply Yourself to the Field Ministry", dot: :attention, parts: [
          Part.new(key: "field_ministry", label: "Field Ministry", fields: %i[ notes ])
        ]),
        Section.new(name: "Living as Christians", dot: :danger, parts: [
          Part.new(key: "living_part", label: "Living as Christians part", fields: %i[ title notes ], repeats: true),
          Part.new(key: "congregation_bible_study", label: "Congregation Bible Study", fields: %i[ notes ])
        ])
      ],
      "weekend" => [
        Section.new(name: "Public Talk", dot: :muted, parts: [
          Part.new(key: "public_talk", label: "Public Talk", fields: %i[ title speaker notes ])
        ]),
        Section.new(name: "Watchtower Study", dot: :danger, parts: [
          Part.new(key: "watchtower_study", label: "Watchtower Study", fields: %i[ title notes ])
        ])
      ]
    }
  }.freeze

  attr_reader :sections

  # An unknown kind has no parts, so a note with one fails its own validation instead of raising here.
  def initialize(kind:, version:)
    @sections = VERSIONS.fetch(version).fetch(kind, [])
  end

  def parts
    sections.flat_map(&:parts)
  end

  def part(key)
    parts.find { it.key == key }
  end
end
