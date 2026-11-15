# A goal put away to look back on, and who did it. Only created through Goal#archive; Goal#restore deletes it.
class Goal::Archival < ApplicationRecord
  belongs_to :goal
  belongs_to :archived_by, class_name: "User"
end
