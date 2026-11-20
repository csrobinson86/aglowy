class DeletePersonalStudyNotes < ActiveRecord::Migration[8.1]
  # A study's own notes give way to its one note in Notes, and nothing is carried over (beta; docs/design/personal-study.md,
  # Decisions). Deleted, so there's nothing to bring back.
  def up
    execute "DELETE FROM action_text_rich_texts WHERE record_type = 'PersonalStudy' AND name = 'notes'"
  end

  def down
  end
end
