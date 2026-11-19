class CreateListeningGamePreparations < ActiveRecord::Migration[8.1]
  # The claim that a run is asking the AI for a household's week (docs/design/listening-game.md, When it runs). No
  # updated_at: taking a claim over moves its created_at.
  def change
    create_table :listening_game_preparations, id: :uuid do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :week_of, null: false
      t.uuid :token, null: false
      t.datetime :created_at, null: false

      t.index %i[ household_id week_of ], unique: true
    end
  end
end
