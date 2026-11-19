# Change a round, in a dialog on This week's listening game (docs/design/listening-game.md, Pages, Change a round; frame
# phone-game-change.png): the card heard in the part with its kind, the three other cards, then Cancel and Save.
class ListeningGames::RoundForm < ApplicationForm
  HEARD_IN = { "talk" => "the talk", "spiritual_gems" => "Spiritual Gems", "bible_reading" => "the reading",
               "congregation_bible_study" => "the study" }.freeze
  KIND_LABELS = { "person" => "Person", "place" => "Place", "book" => "Bible book", "thing" => "Thing", "feeling" => "Feeling",
                  "action" => "Something to do" }.freeze

  def initialize(dialog_id:)
    @dialog_id = dialog_id
  end

  form do |f|
    heard_in = HEARD_IN.fetch(f.builder.object.round.step)

    f.group(layout: :horizontal) do |answer|
      answer.text_field(name: :answer_label, label: "Heard in #{heard_in}", required: true, maxlength: ListeningGame::Card::LABEL_MAX)
      answer.select_list(name: :answer_kind, label: "Kind") do |list|
        KIND_LABELS.each { |value, label| list.option(label:, value:) }
      end
    end
    ListeningGame::Round::Change::LABELS.drop(1).each.with_index(1) do |name, place|
      f.text_field(name:, label: "Other card #{place}", required: true, maxlength: ListeningGame::Card::LABEL_MAX, full_width: true,
                   caption: ("Things from the Bible that aren't in #{heard_in}." if place == 1))
    end
    f.group(layout: :horizontal, justify_content: :flex_end) do |actions|
      actions.button(name: :cancel, label: "Cancel", data: { close_dialog_id: @dialog_id })
      actions.submit(name: :submit, label: "Save", scheme: :primary)
    end
  end
end
