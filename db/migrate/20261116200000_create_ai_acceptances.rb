class CreateAiAcceptances < ActiveRecord::Migration[8.1]
  def change
    # Someone turning on AI drafts, at one version of the terms (docs/design/ai.md, First use). A record, not a boolean.
    create_table :ai_acceptances, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.integer :version, null: false
      t.timestamps

      t.index %i[ user_id version ], unique: true
    end
  end
end
