require "image_processing/vips"

# Only the loaders libvips trusts with uploads (JPEG, PNG, WebP, HEIF among them), never ImageMagick, PDF, MAT, FITS or
# OpenSlide, whatever a file's bytes claim past Marcel (Traps 2).
Vips.block_untrusted(true)

# A person's photo (docs/design/avatars.md, User): only ever the 256 × 256 WebP Aglowy made from their upload, the
# middle square turned upright with no location or camera details. The upload is checked by its bytes and its header
# before anything is decoded, and is never stored (Traps 1–3).
module User::Avatarable
  extend ActiveSupport::Concern

  PHOTO_TYPES = %w[ image/jpeg image/png image/webp image/heic image/heif ]
  PHOTO_MAX_SIZE = 10.megabytes
  PHOTO_MIN_SIDE = 64
  PHOTO_MAX_PIXELS = 50_000_000
  PHOTO_REFUSED = "Choose a JPEG, PNG, WebP or HEIC photo up to 10 MB."
  AVATAR_MAX_SIZE = 100.kilobytes

  included do
    has_one_attached :avatar

    validate :avatar_made_by_aglowy, if: -> { avatar.attached? }
  end

  # Check, build, store. A refused photo adds the message to :avatar and returns false, leaving any photo already there.
  def change_avatar(file)
    return refuse_photo unless photo_acceptable?(file)

    built = ImageProcessing::Vips.source(file.tempfile).autorot.resize_to_fill(256, 256, crop: :centre)
      .convert("webp").saver(strip: true, quality: 80).call
    # In memory (it's at most 100 KB): Active Storage uploads after the outermost commit, by when the file is gone.
    avatar.attach(io: StringIO.new(built.read), filename: "avatar.webp", content_type: "image/webp")
  ensure
    built&.close!
  end

  # The initial shows again.
  def remove_avatar
    avatar.purge
  end

  # The person themselves, or anyone sharing an active household with them, in one query.
  def visible_to?(viewer)
    viewer == self || Membership.active.where(user: viewer).where(household_id: memberships.active.select(:household_id)).exists?
  end

  private
    def refuse_photo
      errors.add(:avatar, PHOTO_REFUSED)
      false
    end

    # The type from the bytes, never the name or the browser's word for it.
    def photo_acceptable?(file)
      file.respond_to?(:tempfile) && file.size <= PHOTO_MAX_SIZE && Marcel::MimeType.for(file).in?(PHOTO_TYPES) && photo_dimensions_acceptable?(file)
    end

    # libvips reads only the header here, so a decompression bomb is refused before it's decoded.
    def photo_dimensions_acceptable?(file)
      header = Vips::Image.new_from_file(file.tempfile.path)
      [ header.width, header.height ].min >= PHOTO_MIN_SIDE && header.width * header.height <= PHOTO_MAX_PIXELS
    rescue Vips::Error
      false
    end

    def avatar_made_by_aglowy
      unless avatar.content_type == "image/webp" && avatar.byte_size <= AVATAR_MAX_SIZE
        errors.add(:avatar, "must be a WebP of at most #{AVATAR_MAX_SIZE / 1.kilobyte} KB")
      end
    end
end
