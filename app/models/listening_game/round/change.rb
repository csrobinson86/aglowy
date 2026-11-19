# A head or adult changing a round for their household (docs/design/listening-game.md, Pages, Change a round): the
# answer's label and kind, and the labels of the three other cards, with the checks a round from the AI passes (each
# label 1 to 40 characters, a known kind, no label twice). Saving keeps every card in its place in the grid and the
# others' kinds, and records who changed it.
class ListeningGame::Round::Change
  include ActiveModel::Model
  include ActiveModel::Attributes

  LABELS = %i[ answer_label other_label_1 other_label_2 other_label_3 ].freeze

  attribute :answer_label, :string
  attribute :answer_kind, :string
  attribute :other_label_1, :string
  attribute :other_label_2, :string
  attribute :other_label_3, :string

  attr_reader :round

  validates(*LABELS, presence: true, length: { maximum: ListeningGame::Card::LABEL_MAX })
  validates :answer_kind, inclusion: { in: ListeningGame::Card::KINDS }
  validate :labels_differ

  def initialize(round, attributes = {})
    @round = round
    super(current_attributes.merge(attributes.to_h.symbolize_keys))
    LABELS.each { |name| public_send(:"#{name}=", public_send(name).to_s.squish) }
  end

  def save(by:)
    return false if invalid?

    round.transaction do
      round.answer.update!(label: answer_label, kind: answer_kind)
      round.others.zip(other_labels).each { |card, label| card.update!(label:) }
      round.update!(changed_by: by)
    end
  end

  def other_labels
    [ other_label_1, other_label_2, other_label_3 ]
  end

  private
    def current_attributes
      { answer_label: round.answer.label, answer_kind: round.answer.kind }
        .merge(round.others.map(&:label).each.with_index(1).to_h { |label, place| [ :"other_label_#{place}", label ] })
    end

    # The second of two cards with the same words (ignoring case) is the one refused.
    def labels_differ
      LABELS.each_with_object([]) do |name, seen|
        label = public_send(name).downcase
        errors.add(name, "is already on another card") if label.present? && seen.include?(label)
        seen << label
      end
    end
end
