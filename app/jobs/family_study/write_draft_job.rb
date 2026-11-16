# Writes a family study draft (FamilyStudy::Draft#write_now). The draft's id only: a prompt never goes in job
# arguments (docs/design/ai.md, Traps).
class FamilyStudy::WriteDraftJob < ApplicationJob
  def perform(draft_id)
    FamilyStudy::Draft.find(draft_id).write_now
  end
end
