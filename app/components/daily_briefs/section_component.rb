# frozen_string_literal: true

# One bordered section of the brief: a small kicker, an h2, a link to read at its source, and rows of a label and what
# goes with it, each reference a scripture link (docs/design/daily-brief.md, The brief; frame brief-base.png). A section
# with no title has nothing to show and isn't drawn. Everything in it is the plan's own words, escaped.
class DailyBriefs::SectionComponent < ApplicationComponent
  Link = Data.define(:text, :href, :note) do
    def initialize(text:, href:, note: nil) = super
  end

  Row = Data.define(:label, :text, :references) do
    def initialize(label:, text:, references: []) = super
  end

  attr_reader :id, :kicker, :title, :link, :rows

  def initialize(kicker:, title:, id: "daily-brief-#{kicker.parameterize}", link: nil, rows: [])
    @id, @kicker, @title, @link, @rows = id, kicker, title, link, rows
  end

  def render?
    title.present?
  end
end
