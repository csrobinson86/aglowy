# Writes a daily brief's AI part (DailyBrief::Writing#write_now). The writing's id only: nothing the person typed goes
# in job arguments (docs/design/ai.md, Traps). Deleting the brief takes its writings with it, so one may be gone by now.
class DailyBrief::WriteJob < ApplicationJob
  def perform(writing_id)
    DailyBrief::Writing.find_by(id: writing_id)&.write_now
  end
end
