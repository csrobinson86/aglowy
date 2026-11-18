# A card in a round: a label in child words and its kind's icon (docs/design/listening-game.md, ListeningGame::Card).
# Labels are AI text, untrusted: always escaped when shown (Trap 4).
class ListeningGame::Card < ApplicationRecord
  # Keep in step with the listening_game_cards_kind_check constraint.
  KINDS = %w[ person place book thing feeling action ].freeze
  LABEL_MAX = 40

  belongs_to :round, class_name: "ListeningGame::Round", inverse_of: :cards

  # An unsaved card from a reply's { label, kind }, or nil when the label isn't a string of 1 to 40 characters or the
  # kind isn't one of KINDS.
  def self.from_reply(card, answer:)
    label, kind = card.values_at("label", "kind") if card.is_a?(Hash)
    new(label: label.squish, kind:, answer:) if label.is_a?(String) && label.squish.length.in?(1..LABEL_MAX) && kind.in?(KINDS)
  end
end
