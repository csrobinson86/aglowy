# A child's drawing for one step of a meeting helper note (docs/design/meeting-helper.md, Models; Drawing). The canvas
# exports a PNG. Served only through MeetingNotes::Steps::DrawingsController#show, never by Active Storage's own
# URLs (gotcha 22). Personal content, so it doesn't count toward the household's storage quota.
class MeetingNote::Drawing < ApplicationRecord
  MAX_SIZE = 2.megabytes

  belongs_to :meeting_note

  has_one_attached :image

  # A check constraint can't see the note's kind or the attachment, which lives in Active Storage's tables.
  validate :step_is_one_of_the_notes
  validate :image_is_a_small_png

  private
    def step_is_one_of_the_notes
      errors.add(:step, "isn't a step of this meeting") unless meeting_note&.helper_steps&.any? { it.key == step }
    end

    # The type is the one Active Storage identified from the file's bytes when it was attached, not the request's
    # (Trap 8).
    def image_is_a_small_png
      if !image.attached?
        errors.add(:image, :blank)
      elsif image.content_type != "image/png"
        errors.add(:image, "must be a PNG")
      elsif image.byte_size > MAX_SIZE
        errors.add(:image, "must be #{ActiveSupport::NumberHelper.number_to_human_size(MAX_SIZE)} or smaller")
      end
    end
end
