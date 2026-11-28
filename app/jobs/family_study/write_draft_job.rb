# Writes a family study draft (FamilyStudy::Draft#write_now). The draft's id only: a prompt never goes in job
# arguments (docs/design/ai.md, Traps). A draft goes with its household and its chat, so one may be gone by now.
class FamilyStudy::WriteDraftJob < ApplicationJob
  def perform(draft_id)
    FamilyStudy::Draft.find_by(id: draft_id)&.write_now
  end
end
