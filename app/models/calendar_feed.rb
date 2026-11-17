# A person's private subscribe link, /calendar/<token>.ics (docs/design/calendar.md, CalendarFeed). The token is the
# only authorization the feed has, so it's encrypted in the database and Reset replaces it at once.
class CalendarFeed < ApplicationRecord
  belongs_to :user

  has_secure_token
  encrypts :token, deterministic: true

  def reset
    regenerate_token
  end

  def to_ics
    CalendarFeed::Document.new(user).to_s
  end
end
