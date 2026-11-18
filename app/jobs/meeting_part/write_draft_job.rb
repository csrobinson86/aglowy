# Writes a meeting part draft (MeetingPart::Draft#write_now). The draft's id only: a request never goes in job
# arguments (docs/design/ai.md, Traps).
class MeetingPart::WriteDraftJob < ApplicationJob
  def perform(draft_id)
    MeetingPart::Draft.find(draft_id).write_now
  end
end
