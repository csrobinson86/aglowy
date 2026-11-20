# That an answer is in its study's note, as a record (docs/design/personal-study.md, PersonalStudy::Question::NoteSaving).
# One per answer. The database deletes it with the answer or the note, so once the note is gone each answer can be
# saved again, into a new note.
class PersonalStudy::Question::NoteSaving < ApplicationRecord
  belongs_to :question, class_name: "PersonalStudy::Question"
  belongs_to :personal_note
end
