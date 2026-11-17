# "Mark all as read" in the inbox's header.
class Notifications::ReadingForm < ApplicationForm
  form do |f|
    f.submit(name: :mark_all_as_read, label: "Mark all as read")
  end
end
