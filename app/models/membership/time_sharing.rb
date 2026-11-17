# A person's times shown on that household's calendar, as a record: it exists while they share, and only counts while
# the seat is active (docs/design/calendar.md, Membership::TimeSharing). Made by Membership#share_times and deleted by
# Membership#stop_sharing_times. Members there see each time's title and when it is, nothing else (Trap 3).
class Membership::TimeSharing < ApplicationRecord
  belongs_to :membership
end
