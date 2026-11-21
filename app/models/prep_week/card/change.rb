# A head or adult changing a Get ready card for their household (docs/design/meeting-prep.md, Pages and routes, Change
# a card): what it's about, the quality and how it shows, I can…, and on the Bible Reading card the reading and up to
# four story sentences. A parent's change is held only to the columns' lengths, not the AI's word limits, so the
# reading and story can be cleared. Saving records who changed it.
class PrepWeek::Card::Change
  include ActiveModel::Model
  include ActiveModel::Attributes

  TEXTS = %i[ about quality_line i_can reading ].freeze
  SENTENCES = (1..PrepWeek::Card::STORY_SENTENCES).map { :"story_#{it}" }.freeze

  attribute :about, :string
  attribute :quality, :string
  attribute :quality_line, :string
  attribute :i_can, :string
  attribute :reading, :string
  SENTENCES.each { attribute it, :string }

  attr_reader :card

  validates :about, :quality_line, :i_can, presence: true
  PrepWeek::Card::LENGTHS.each { |field, most| validates field, length: { maximum: most } }
  validates(*SENTENCES, length: { maximum: PrepWeek::Card::SENTENCE_LENGTH })
  validates :quality, inclusion: { in: PrepWeek::Card::QUALITIES.keys }

  def initialize(card, attributes = {})
    @card = card
    super(current_attributes.merge(attributes.to_h.symbolize_keys))
    (TEXTS + SENTENCES).each { |name| public_send(:"#{name}=", public_send(name).to_s.squish) }
  end

  def save(by:)
    return false if invalid?

    card.update!(about:, quality:, quality_line:, i_can:, **reading_and_story, changed_by: by)
  end

  def bible_reading?
    card.step == "bible_reading"
  end

  private
    def current_attributes
      card.slice(:about, :quality, :quality_line, :i_can, :reading).symbolize_keys
        .merge(SENTENCES.zip(Array(card.story)).to_h)
    end

    # Only the Bible Reading card has a reading and a story; a cleared one is nil, as the AI leaves it on other cards.
    def reading_and_story
      return {} unless bible_reading?

      { reading: reading.presence, story: SENTENCES.map { public_send(it) }.compact_blank.presence }
    end
end
