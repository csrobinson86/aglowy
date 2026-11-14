class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households, id: :uuid do |t|
      t.string :name, null: false
      t.string :time_zone, null: false, default: "UTC"

      t.timestamps
    end
  end
end
