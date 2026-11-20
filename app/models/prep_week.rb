# One week's Get ready cards for one household (docs/design/meeting-prep.md, PrepWeek): a card for each of five parts of
# the week's two meetings, and the pages the AI used to write them. Filled in by Household#prepare_meeting_prep; its
# chat goes after 7 days, and the week stays 8 weeks.
class PrepWeek < ApplicationRecord
  # By the week each is for, so a week stays 8 whole weeks after its own (PrepWeek::PurgeJob).
  KEEP_FOR = 8.weeks

  belongs_to :household
  belongs_to :chat, optional: true
  # The database deletes cards and sources with their week (on_delete: :cascade).
  has_many :cards, -> { in_order_of(:step, PrepWeek::Card::STEPS.keys) }, inverse_of: :prep_week
  has_many :sources, -> { order(:position) }, inverse_of: :prep_week

  scope :preloaded, -> { includes(:cards, :sources) }
  scope :expired, -> { where(week_of: ...Date.current.beginning_of_week(:monday) - KEEP_FOR) }

  # The cards a reply's fields hold for +steps+, as attributes for PrepWeek::Card: each step once, the first card for it
  # that passes PrepWeek::Card.attributes_from_reply (docs/design/meeting-prep.md, Checks before saving).
  def self.cards_from_reply(fields, steps:, copy_check:)
    Array(fields["cards"]).filter_map { PrepWeek::Card.attributes_from_reply(it, copy_check:) }
      .select { it[:step].in?(steps) }.uniq { it[:step] }
  end

  # Saves the cards for steps that still have none, never touching a saved card (a parent's change is kept), with the
  # pages not yet linked and the chat that asked. Self, or nil when no card is new: then nothing is saved, and a new week
  # isn't made.
  def fill_in(new_cards, pages:, chat:)
    new_cards = new_cards.reject { it[:step].in?(cards.map(&:step)) }
    return if new_cards.none?

    new_cards.each { cards.build(it) }
    link(pages)
    update!(chat:)
    self
  end

  def cards_for(meeting)
    cards.select { it.meeting == meeting }
  end

  private
    # A page already linked isn't linked twice, and one whose search result has no title is left out, rather than
    # losing the cards to the not-null title.
    def link(pages)
      linked = sources.map(&:url)
      pages.select { it[:title].present? && !it[:url].in?(linked) }
        .each.with_index(sources.size + 1) { |page, position| sources.build(position:, **page.slice(:url, :title)) }
    end
end
