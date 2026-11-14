# The shape of a meeting's notes, defined in code rather than the database. A note keeps the
# outline_version it was built with, so a new format gets a new version and old notes keep theirs.
# The edit page is drawn from it, so the form's labels, placeholders and hints live here too.
# A section's dot is a Primer functional colour (the fgColor-* tokens).
class MeetingNote::Outline
  Section = Data.define(:name, :dot, :parts)

  # One input of a part: :title, :speaker, :notes (a Lexxy editor; tall for notes taken through a
  # whole talk) or :gems (the note's Spiritual Gems). The label defaults to the field's name.
  Field = Data.define(:name, :label, :placeholder, :tall) do
    def initialize(name:, label: name.to_s.humanize, placeholder: nil, tall: false)
      super
    end

    alias_method :tall?, :tall

    def default_label?
      label == name.to_s.humanize
    end
  end

  # fields takes a Field, or a field's name for one with the default label and no placeholder.
  Part = Data.define(:key, :label, :fields, :repeats, :hint) do
    def initialize(key:, label:, fields:, repeats: false, hint: nil)
      super(key:, label:, repeats:, hint:, fields: fields.map { it.is_a?(Field) ? it : Field.new(name: it) })
    end

    alias_method :repeats?, :repeats

    def field(name)
      fields.find { it.name == name }
    end
  end

  VERSIONS = {
    # Life and Ministry checked against the meeting instructions, S-38 8/26.
    1 => {
      "midweek" => [
        Section.new(name: "Treasures From God's Word", dot: :muted, parts: [
          Part.new(key: "talk", label: "Talk", fields: %i[ title notes ]),
          Part.new(key: "spiritual_gems", label: "Spiritual Gems", fields: %i[ gems ], hint: "Each gem is a scripture and what you found in it"),
          Part.new(key: "bible_reading", label: "Bible Reading", fields: [
            Field.new(name: :notes, placeholder: "Anything from the reading you want to remember.")
          ])
        ]),
        Section.new(name: "Apply Yourself to the Field Ministry", dot: :attention, parts: [
          Part.new(key: "field_ministry", label: "Field Ministry", fields: [
            Field.new(name: :notes, label: "Notes for the whole section", placeholder: "Openings, questions or approaches you'd like to try.")
          ])
        ]),
        Section.new(name: "Living as Christians", dot: :danger, parts: [
          Part.new(key: "living_part", label: "Living as Christians part", repeats: true, fields: [
            Field.new(name: :title, label: "Part title", placeholder: "As it appears in the workbook"), :notes
          ]),
          Part.new(key: "congregation_bible_study", label: "Congregation Bible Study", fields: %i[ notes ])
        ])
      ],
      "weekend" => [
        Section.new(name: "Public Talk", dot: :muted, parts: [
          Part.new(key: "public_talk", label: "Public Talk", fields: [
            Field.new(name: :title, label: "Talk title", placeholder: "The title the speaker announces"),
            Field.new(name: :speaker, placeholder: "Optional"),
            Field.new(name: :notes, placeholder: "Type as the speaker goes: main points, scriptures read, anything to apply.", tall: true)
          ])
        ]),
        Section.new(name: "Watchtower Study", dot: :danger, parts: [
          Part.new(key: "watchtower_study", label: "Watchtower Study",
                   hint: "Follow along and mark your answers in JW Library. Keep anything you want to remember here.", fields: [
            Field.new(name: :title, label: "Article title", placeholder: "Optional"),
            Field.new(name: :notes, label: "A point to remember")
          ])
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
