# The type and size rule for a file resource, in one place (docs/design/family-studies.md, Limits).
# Asked of a direct-upload request before any bytes go up (gotcha 24), then of the attached file.
class FamilyStudy::Resource::FileCheck
  NOT_ALLOWED = "must be a PDF or an image (PNG, JPEG, GIF, WebP or HEIC)"

  def initialize(content_type:, byte_size:)
    @content_type = content_type
    @byte_size = byte_size.to_i
  end

  # Nil when the file is fine.
  def problem
    if !@content_type.in?(config.file_types)
      NOT_ALLOWED
    elsif @byte_size > config.max_file_size
      "must be #{ActiveSupport::NumberHelper.number_to_human_size(config.max_file_size)} or smaller"
    end
  end

  private
    def config
      Rails.configuration.x.family_studies
    end
end
