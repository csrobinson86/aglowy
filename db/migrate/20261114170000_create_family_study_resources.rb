class CreateFamilyStudyResources < ActiveRecord::Migration[8.1]
  def change
    create_table :family_study_resources, id: :uuid do |t|
      t.references :session, type: :uuid, null: false, foreign_key: { to_table: :family_study_sessions }
      t.string :kind, null: false
      t.string :url
      t.string :title, null: false
      t.integer :position

      t.timestamps
    end

    # Files arrive in the next story; the check already allows them.
    add_check_constraint :family_study_resources, "kind IN ('link', 'file')", name: "family_study_resources_kind_check"
    # A backstop for the model, which judges the parsed scheme (gotcha 23).
    add_check_constraint :family_study_resources, "kind <> 'link' OR (url IS NOT NULL AND url ~* '^https?://')", name: "family_study_resources_url_check"
  end
end
