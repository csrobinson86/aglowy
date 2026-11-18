# frozen_string_literal: true

# One bordered section of the brief: a small kicker, an h2, a link to read at its source, and rows of a label and what
# goes with it, each reference a scripture link (docs/design/daily-brief.md, The brief; frame brief-base.png). A section
# with no title has nothing to show and isn't drawn. Everything in it is the plan's own words, escaped.
class DailyBriefs::SectionComponent < ApplicationComponent
  # A link to read at its source opens in a new tab; one to another part of the brief (external: false) doesn't.
  Link = Data.define(:text, :href, :note, :external) do
    def initialize(text:, href:, note: nil, external: true) = super
  end

  # A note is Aglowy's own line under the row, never the AI's: a linked goal's next step.
  Row = Data.define(:label, :text, :references, :note) do
    def initialize(label:, text:, references: [], note: nil) = super

    # Nothing to show: an AI field the checks left empty, with no scripture.
    def blank? = text.blank? && references.empty?
  end

  attr_reader :id, :kicker, :title, :link, :rows

  def initialize(kicker:, title:, id: "daily-brief-#{kicker.parameterize}", link: nil, rows: [])
    @id, @kicker, @title, @link, @rows = id, kicker, title, link, rows.reject(&:blank?)
  end

  def render?
    title.present?
  end
end
