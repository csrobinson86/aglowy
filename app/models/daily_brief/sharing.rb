# Today's thought shared, read-only, with one household: the thread, the reading and the children's box. Only created
# through DailyBrief#share_with, and it makes no notification (docs/design/daily-brief.md, For the children, and sharing).
class DailyBrief::Sharing < ApplicationRecord
  belongs_to :daily_brief
  belongs_to :household
end
