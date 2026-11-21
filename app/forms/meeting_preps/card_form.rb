# Change a card, in a dialog on This week's Get ready cards (docs/design/meeting-prep.md, Pages and routes, Change a
# card; frame phone-prep-change.png): what it's about, Jehovah is… as a select of the ten qualities, how it shows,
# I can…, and on the Bible Reading card the reading and its story sentences, then Cancel and Save.
class MeetingPreps::CardForm < ApplicationForm
  def initialize(dialog_id:)
    @dialog_id = dialog_id
  end

  form do |f|
    lengths = PrepWeek::Card::LENGTHS

    f.text_area(name: :about, label: "What it's about", required: true, maxlength: lengths[:about], full_width: true)
    f.select_list(name: :quality, label: "Jehovah is…", full_width: true) do |list|
      PrepWeek::Card::QUALITIES.each { |value, quality| list.option(label: quality[:words], value:) }
    end
    f.text_field(name: :quality_line, label: "How it shows", required: true, maxlength: lengths[:quality_line], full_width: true)
    f.text_field(name: :i_can, label: "I can…", required: true, maxlength: lengths[:i_can], full_width: true)
    if f.builder.object.bible_reading?
      f.text_field(name: :reading, label: "The reading", maxlength: lengths[:reading], full_width: true)
      PrepWeek::Card::Change::SENTENCES.each.with_index(1) do |name, place|
        f.text_field(name:, label: "Story sentence #{place}", maxlength: PrepWeek::Card::SENTENCE_LENGTH, full_width: true)
      end
    end
    f.group(layout: :horizontal, justify_content: :flex_end) do |actions|
      actions.button(name: :cancel, label: "Cancel", data: { close_dialog_id: @dialog_id })
      actions.submit(name: :submit, label: "Save", scheme: :primary)
    end
  end
end
