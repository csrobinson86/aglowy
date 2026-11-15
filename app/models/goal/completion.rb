# A goal marked complete, and who did it. Only created through Goal#complete; Goal#reopen deletes it.
class Goal::Completion < ApplicationRecord
  belongs_to :goal
  belongs_to :completed_by, class_name: "User"
end
