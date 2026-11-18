# Writes a meeting part draft (MeetingPart::Draft#write_now). The draft's id only: a request never goes in job
# arguments (docs/design/ai.md, Traps). Deleting the part takes its drafts with it, so one may be gone by now.
class MeetingPart::WriteDraftJob < ApplicationJob
  def perform(draft_id)
    MeetingPart::Draft.find_by(id: draft_id)&.write_now
  end
end
