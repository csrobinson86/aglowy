# "Remove photo" in the Avatar box, beside Change photo (frame settings-avatar-photo.png).
class Settings::AvatarRemovalForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Remove photo", scheme: :danger)
  end
end
