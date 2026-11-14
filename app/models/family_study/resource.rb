class FamilyStudy::Resource < ApplicationRecord
  NOT_A_WEB_LINK = "must be a web address starting with http:// or https://"

  belongs_to :session, class_name: "FamilyStudy::Session"

  enum :kind, %w[ link file ].index_by(&:itself), default: :link, validate: true

  # Served only through Resources::FilesController, never by Active Storage's own URLs (gotcha 22).
  has_one_attached :file

  # Links copied from jw.org in other languages carry characters URI won't parse; encode them as a browser does.
  normalizes :url, with: -> { it.strip.gsub(/[^\x21-\x7E]|["<>\\^`{|}]/) { |char| char.bytes.map { format("%%%02X", it) }.join } }

  before_validation :default_title_from_url, if: :link?
  before_validation :default_title_from_file, if: :file?
  before_create :place_last

  validates :title, presence: true
  validate :url_is_a_web_link, if: :link?
  # In the model: the attachment lives in Active Storage's tables, where a check constraint can't see it.
  validate :file_is_allowed, if: :file?
  # Only when the file is added: a saved file already counts towards what the household uses.
  validate :file_fits_household_storage, on: :create, if: -> { file? && file.attached? }

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

    # Escapes that don't decode to valid UTF-8 ("%FF") or decode to control characters ("%00", "%0A") stay escaped.
    def readable_path
      URI.decode_uri_component(parsed_url.path).then { it.valid_encoding? && !it.match?(/[[:cntrl:]]/) ? it : parsed_url.path }
    end

    def default_title_from_file
      self.title = file.filename.to_s if title.blank? && file.attached?
    end

    def place_last
      self.position ||= (session.resources.maximum(:position) || 0) + 1
    end

    def url_is_a_web_link
      errors.add(:url, NOT_A_WEB_LINK) unless web_link?
    end

    # The type is the one Active Storage identified from the file's bytes when it was attached.
    def file_is_allowed
      if file.attached?
        problem = FileCheck.new(content_type: file.content_type, byte_size: file.byte_size).problem
        errors.add(:file, problem) if problem
      else
        errors.add(:file, :blank)
      end
    end

    # A sentence of its own, so it goes on the resource rather than after "File".
    def file_fits_household_storage
      household = session.family_study.household
      errors.add(:base, household.storage_full_message) unless household.fits_in_storage?(file.byte_size)
    end
end
