class CreateBookmarks < ActiveRecord::Migration[8.1]
  # One person's saved jw.org page or scripture (docs/design/bookmarks.md, Bookmark). Each is one or the other, once per
  # person. Title and comment are encrypted, so their lengths are checked by validations only. Deleting a collection
  # keeps its bookmarks, out of any folder; deleting the study or note they came from is nullified by the model.
  def change
    create_table :bookmarks, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :url
      t.string :scripture
      t.string :title
      t.string :comment
      t.references :collection, foreign_key: { on_delete: :nullify }, type: :uuid
      t.references :source, polymorphic: true, type: :uuid
      t.timestamps

      t.index %i[ user_id url ], unique: true
      t.index %i[ user_id scripture ], unique: true
      t.index %i[ user_id created_at ]

      t.check_constraint "num_nonnulls(url, scripture) = 1", name: "bookmarks_page_or_scripture_check"
      t.check_constraint "url ~ '^https://(www\\.)?(jw\\.org|wol\\.jw\\.org)/'", name: "bookmarks_url_check"
      t.check_constraint "scripture ~ '^\\d+:\\d+(:\\d+(-\\d+)?)?$'", name: "bookmarks_scripture_check"
      t.check_constraint "num_nonnulls(source_type, source_id) <> 1", name: "bookmarks_source_together_check"
      t.check_constraint "source_type IN ('PersonalStudy', 'PersonalNote')", name: "bookmarks_source_type_check"
    end
  end
end
