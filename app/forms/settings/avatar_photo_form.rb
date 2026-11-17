# "Save avatar" in the preview dialog's footer (frame avatar-preview.png). The photo is in the hand-built file input of
# the same primer_form_with: Primer forms have no file input (CLAUDE.md, Forms, the photo picker exception).
class Settings::AvatarPhotoForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Save avatar", scheme: :primary, data: { avatar_preview_target: "save" })
  end
end
