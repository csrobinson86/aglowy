class CreateGoBags < ActiveRecord::Migration[8.1]
  # A household's emergency bags (docs/design/go-bags.md, GoBag). The name and where it's kept are encrypted, so their
  # lengths are checked by validations only. Someone leaving clears for_user_id in Membership#deactivate; the database
  # clears it if the person is deleted.
  def change
    create_table :go_bags, id: :uuid do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :name, null: false
      t.string :kept_at
      t.references :for_user, foreign_key: { to_table: :users, on_delete: :nullify }, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.timestamps
    end
  end
end
