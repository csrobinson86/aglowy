class AddPersonalStudyToPersonalNotes < ActiveRecord::Migration[8.1]
  # The study this note is the note of (docs/design/notes.md, PersonalNote). One note per study, which the study's
  # lock relies on; deleting the study keeps the note and drops the link.
  def change
    add_reference :personal_notes, :personal_study, type: :uuid, foreign_key: { on_delete: :nullify },
      index: { unique: true, where: "personal_study_id IS NOT NULL" }
  end
end
