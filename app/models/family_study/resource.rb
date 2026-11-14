class FamilyStudy::Resource < ApplicationRecord
  NOT_A_WEB_LINK = "must be a web address starting with http:// or https://"

  belongs_to :session, class_name: "FamilyStudy::Session"

  # Files arrive in the next story; the database check already allows them.
  enum :kind, %w[ link ].index_by(&:itself), default: :link, validate: true

  # Links copied from jw.org in other languages carry characters URI won't parse; encode them as a browser does.
  normalizes :url, with: -> { it.strip.gsub(/[^\x21-\x7E]|["<>\\^`{|}]/) { |char| char.bytes.map { format("%%%02X", it) }.join } }

  before_validation :default_title_from_url, if: :link?
  before_create :place_last

  validates :title, presence: true
  validate :url_is_a_web_link, if: :link?

  # Gotcha 23: judged on the parsed scheme, never by matching the start of the string.
  def web_link?
    parsed_url.is_a?(URI::HTTP) && parsed_url.host.present?
  end

  def host
    parsed_url&.host
  end

  private
    def parsed_url
      URI.parse(url.to_s)
    rescue URI::InvalidURIError
      nil
    end

    # "www.jw.org/en/library/bible", without the query or a trailing slash, and readable ("año", not "a%C3%B1o").
    def default_title_from_url
      self.title = "#{host}#{readable_path.chomp("/")}" if title.blank? && web_link?
    end

    # Escapes that don't decode to valid UTF-8 ("%FF") stay escaped.
    def readable_path
      URI.decode_uri_component(parsed_url.path).then { it.valid_encoding? ? it : parsed_url.path }
    end

    def place_last
      self.position ||= (session.resources.maximum(:position) || 0) + 1
    end

    def url_is_a_web_link
      errors.add(:url, NOT_A_WEB_LINK) unless web_link?
    end
end
