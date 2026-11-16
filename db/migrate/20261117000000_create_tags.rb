class CreateTags < ActiveRecord::Migration[8.1]
  def change
    # One person's tag, shown as #name (docs/design/tags.md, Tag). Tag.normalize makes names that pass the check.
    create_table :tags, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :name, null: false
      t.timestamps

      t.index %i[ user_id name ], unique: true
      t.check_constraint "name ~ '^[a-z0-9][a-z0-9-]{0,29}$'", name: "tags_name_check"
    end
  end
end
