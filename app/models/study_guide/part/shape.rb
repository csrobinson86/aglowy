# The fields a study guide part has for its step, and their limits (docs/design/study-guide.md, Ai::Purpose::StudyGuide):
# its texts, and its lists of points, each { text, ref } with the list's label besides. StudyGuide::Part checks saved
# content against it, and content_from_reply makes content from a reply, through the checks before saving.
class StudyGuide::Part::Shape
  # The most words in each text, counted as text.split.size.
  WORDS = { "glance" => 40, "title" => 12, "summary" => 50, "reading" => 12, "text" => 30, "quality" => 3, "paragraphs" => 3, "paragraph" => 3 }.freeze
  # A part without its own one of these is dropped, so its step stays missing; a title that fails just goes.
  REQUIRED = %w[ glance summary reading ].freeze

  # Each list: how many points it may have, and the label each point needs besides its text, if any.
  OVERVIEW = { texts: %w[ glance ], lists: { "jehovah" => [ 1..4, "quality" ] } }.freeze
  APPLY = { texts: %w[ title summary ], lists: { "apply" => [ 0..3 ] } }.freeze
  STUDY = { texts: %w[ title summary ], lists: { "notes" => [ 0..8, "paragraphs" ], "jehovah" => [ 0..2 ], "comments" => [ 0..4, "paragraph" ] } }.freeze
  SHAPES = {
    "midweek_overview" => OVERVIEW,
    "talk" => { texts: %w[ title summary ], lists: { "points" => [ 0..4 ], "jehovah" => [ 0..2 ] } },
    "spiritual_gems" => { texts: %w[ summary ], lists: { "comments" => [ 2..4 ] } },
    "bible_reading" => { texts: %w[ reading summary ], lists: { "happens" => [ 0..4 ], "teaches" => [ 0..3 ], "apply" => [ 0..3 ] } },
    "field_ministry" => APPLY,
    "living" => APPLY,
    "congregation_bible_study" => STUDY,
    "weekend_overview" => OVERVIEW,
    "watchtower_study" => STUDY
  }.freeze

  attr_reader :texts, :lists

  def initialize(step)
    @texts, @lists = SHAPES.fetch(step).values_at(:texts, :lists)
  end

  # Fields only from this shape: each text it needs, any other within its words, and each list within its count, every
  # point with its text and label within their words and any ref a real reference. A list left out has no points.
  def fits?(content)
    content.is_a?(Hash) && (content.keys - texts - lists.keys).none? &&
      texts.all? { |name| content.key?(name) ? words?(content[name], name) : !name.in?(REQUIRED) } &&
      lists.all? { |name, (counts, label)| list_fits?(content.fetch(name, []), counts, label) }
  end

  # The content a reply's fields make, or nil when it doesn't fit: each reference ours, or gone with its point kept; web
  # addresses taken out; texts squished, and any the copy check touches gone with their point (a title goes on its own,
  # as one over its words does); points over their words gone, and each list cut to its most.
  def content_from_reply(fields, copy_check:)
    return unless fields.is_a?(Hash)

    fields = Ai::ScriptureFilter.new(scripture_fields: %w[ ref ]).keep(fields)
    content = texts.index_with { text_from_reply(fields[it], it, copy_check:) }
      .merge(lists.to_h { |name, (counts, label)| [ name, points_from_reply(fields[name], counts.max, label, copy_check:) ] })
      .compact_blank
    content if fits?(content)
  end

  private
    def words?(text, name)
      text.is_a?(String) && text.split.size.in?(1..WORDS.fetch(name))
    end

    def list_fits?(points, counts, label)
      points.is_a?(Array) && points.size.in?(counts) && points.all? { point_fits?(it, label) }
    end

    def point_fits?(point, label)
      point.is_a?(Hash) && (point.keys - [ "text", "ref", label ]).none? && words?(point["text"], "text") &&
        (label.nil? || words?(point[label], label)) && (!point.key?("ref") || Bible::Reference.parse(point["ref"]).present?)
    end

    def text_from_reply(text, name, copy_check:)
      text = text.squish if text.is_a?(String)
      text if words?(text, name) && !copy_check.clean(text).last
    end

    def points_from_reply(points, most, label, copy_check:)
      Array(points).grep(Hash).filter_map { point_from_reply(it, label, copy_check:) }.first(most)
    end

    def point_from_reply(point, label, copy_check:)
      kept = { "text" => text_from_reply(point["text"], "text", copy_check:) }
      kept[label] = text_from_reply(point[label], label, copy_check:) if label
      kept["ref"] = point["ref"] if point["ref"]
      kept if kept.values.all?
    end
end
