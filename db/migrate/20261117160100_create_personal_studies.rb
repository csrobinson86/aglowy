class CreatePersonalStudies < ActiveRecord::Migration[8.1]
  def change
    # One person's research on one topic (docs/design/personal-study.md, PersonalStudy). The conversation's chat_id
    # comes with the next story; deleting a collection keeps its studies, out of any folder.
    create_table :personal_studies, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :collection, foreign_key: { on_delete: :nullify }, type: :uuid
      t.string :title, null: false
      t.datetime :last_asked_at
      t.timestamps

      t.check_constraint "char_length(title) BETWEEN 1 AND 120", name: "personal_studies_title_length_check"
    end
  end
end
