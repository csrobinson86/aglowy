# One week's listening game for one household (docs/design/listening-game.md, Models): rounds of four cards for the
# meeting helper's four midweek game steps, and the pages the AI used to find them. Made by
# Household#prepare_listening_game; its chat goes after 7 days, and the game stays.
class ListeningGame < ApplicationRecord
  # The helper steps that become a game, and the most rounds each takes, in the order the meeting has them.
  # Keep in step with the listening_game_rounds_step_check constraint.
  ROUNDS = { "talk" => 5, "spiritual_gems" => 2, "bible_reading" => 2, "congregation_bible_study" => 6 }.freeze
  STEPS = ROUNDS.keys.freeze

  belongs_to :household
  belongs_to :chat, optional: true
  # The database deletes rounds, cards and sources with their game (on_delete: :cascade).
  has_many :rounds, -> { in_order_of(:step, STEPS).order(:position) }, inverse_of: :listening_game
  has_many :sources, -> { order(:position) }, inverse_of: :listening_game

  scope :preloaded, -> { includes(:sources, rounds: :cards) }

  # The game from a reply's fields, with each round that passes ListeningGame::Round.from_reply and the pages that
  # passed Ai::SourceLink, or nil when no step has a round. Rounds that fail leave no gap: the next moves up.
  def self.build_from_reply(fields, sources:, copy_check:, **attributes)
    new(attributes).tap do |game|
      STEPS.each do |step|
        Array(fields[step]).first(ROUNDS[step]).filter_map { ListeningGame::Round.from_reply(it, copy_check:) }
          .each.with_index(1) { |cards, position| game.rounds.build(step:, position:, cards:) }
      end
      # A page whose search result has no title is left out, rather than losing the game to the not-null title.
      sources.select { it[:title].present? }.each.with_index(1) { |source, position| game.sources.build(position:, **source.slice(:url, :title)) }
    end.then { it if it.rounds.any? }
  end
end
