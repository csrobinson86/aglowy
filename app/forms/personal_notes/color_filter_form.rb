# The color filter beside Notes' search (docs/design/notes.md, Colors): toggle buttons drawn as swatches, "Any color"
# then "Only yellow notes" and so on, each naming itself to screen readers. The group is named by the "Color" beside
# it on the page. Each sets ?color= and keeps the collection, tag and search. Class names come from the list of
# colors, never from params (Traps).
class PersonalNotes::ColorFilterForm < ApplicationForm
  def initialize(color:, query:, collection:, tag:)
    @color = color
    @query = query
    @collection = collection
    @tag = tag
  end

  form do |f|
    f.hidden(name: :q, value: @query) if @query
    f.hidden(name: :collection, value: @collection) if @collection
    f.hidden(name: :tag, value: @tag) if @tag
    f.group(layout: :horizontal, role: "group", aria: { labelledby: "note-color-filter-label" }, classes: "note-color-filter") do |buttons|
      buttons.submit(**button(nil, "Any color"))
      PersonalNote::FILTER_COLORS.each { buttons.submit(**button(it, "Only #{it} notes")) }
    end
  end

  private

  def button(color, label)
    { name: :color, value: color.to_s, label:, aria: { pressed: (color == @color).to_s },
      classes: "note-color-filter__button note-color-filter__button--#{color || "any"}" }
  end
end
