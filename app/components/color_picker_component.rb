# frozen_string_literal: true

# The color picker, the approved hand-built radio group drawn as swatches (CLAUDE.md, Forms): a real labelled radio
# for each color, in a fieldset with its legend, inside a Primer form. The chosen color's name shows beside them, so
# color is never the only signal. Notes pick their color with it (docs/design/notes.md, Colors; frame note.png), and
# people their initial's (docs/design/avatars.md, The Avatar box; frame settings-avatar.png).
#
# name:          the radios' field name, like personal_note[color]
# selected:      the chosen color, one of colors
# colors:        the colors to offer: PersonalNote.colors.keys, or Avatar::Palette::COLORS
# legend:        the fieldset's legend, like "Color"
# swatch_label:  text drawn in each swatch, like the person's initial; the swatch then takes the avatar's colors
# legend_beside: the legend on the swatches' line, as on a note, rather than above them
# id_prefix:     the radios' ids before the color, when a page has several pickers of one name (Settings → Children)
class ColorPickerComponent < ApplicationComponent
  attr_reader :name, :selected, :colors, :legend, :swatch_label, :legend_beside

  def initialize(name:, selected:, colors:, legend:, swatch_label: nil, legend_beside: false, id_prefix: nil)
    @name = name
    @selected = selected
    @colors = colors
    @legend = legend
    @swatch_label = swatch_label
    @legend_beside = legend_beside
    @id_prefix = id_prefix || name.parameterize(separator: "_")
  end

  def input_id(color)
    "#{@id_prefix}_#{color}"
  end

  def swatch_classes(color)
    [ "color-picker__swatch", "color-picker__swatch--#{color}", ("color-picker__swatch--labelled" if swatch_label) ]
  end
end
