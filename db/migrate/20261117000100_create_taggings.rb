class CreateTaggings < ActiveRecord::Migration[8.1]
  def change
    # A tag on one of its person's things (docs/design/tags.md, Tagging). Deleting the tag deletes its taggings.
    # PersonalStudy arrives with PSTUDY-01; the owner check is a validation, as a polymorphic link can't have a foreign key.
    create_table :taggings, id: :uuid do |t|
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.references :taggable, null: false, polymorphic: true, type: :uuid
      t.datetime :created_at, null: false

      t.index %i[ tag_id taggable_type taggable_id ], unique: true
      t.check_constraint "taggable_type IN ('MeetingNote', 'Goal', 'PersonalStudy')", name: "taggings_taggable_type_check"
    end
  end
end
