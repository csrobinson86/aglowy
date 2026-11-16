# frozen_string_literal: true

# The note color picker, the approved hand-built radio group drawn as swatches (CLAUDE.md, Forms; frame note.png):
# a real labelled radio for each of a note's colors, in a fieldset with the legend "Color", inside the note's Primer
# form. The chosen color's name shows beside them, so color is never the only signal (docs/design/notes.md, Colors).
#
# name:      the radios' field name, like personal_note[color]
# selected:  the chosen color, one of PersonalNote.colors
class NoteColorPickerComponent < ApplicationComponent
  attr_reader :name, :selected

  def initialize(name:, selected:)
    @name = name
    @selected = selected
  end

  def colors
    PersonalNote.colors.keys
  end

  def input_id(color)
    "#{name.parameterize(separator: "_")}_#{color}"
  end
end
