# One round of a game step: four cards in a grid, one the part mentions (docs/design/listening-game.md,
# ListeningGame::Round).
class ListeningGame::Round < ApplicationRecord
  CARDS = 4

  belongs_to :listening_game
  belongs_to :changed_by, class_name: "User", optional: true
  # The database deletes cards with their round (on_delete: :cascade).
  has_many :cards, -> { order(:position) }, inverse_of: :round

  # A round from the reply ({ answer: { label, kind }, others: [three of them] }) as four unsaved cards shuffled into the
  # grid, or nil when it fails the checks before saving: exactly one answer and three others, every label a string the
  # database can hold, no label twice, every kind known, and nothing the copy check removes
  # (docs/design/listening-game.md, What it asks).
  def self.from_reply(round, copy_check:)
    return unless round.is_a?(Hash) && round["answer"].is_a?(Hash) && round["others"].is_a?(Array) && round["others"].size == CARDS - 1

    cards = [ ListeningGame::Card.from_reply(round["answer"], answer: true), *round["others"].map { ListeningGame::Card.from_reply(it, answer: false) } ]
    return unless cards.all? && cards.map { it.label.downcase.squish }.uniq.size == CARDS
    return if copy_check.clean(cards.map(&:label)).last

    cards.shuffle.each.with_index(1) { |card, position| card.position = position }
  end

  def answer
    cards.find(&:answer?)
  end

  def others
    cards.reject(&:answer?)
  end

  # Its step in the midweek meeting helper, for the step's title.
  def helper_step
    MeetingNote::HelperSteps.for("midweek").fetch(step)
  end
end
