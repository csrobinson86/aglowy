class CreateMeetingParts < ActiveRecord::Migration[8.1]
  # Each person's student parts in Apply Yourself to the Field Ministry (docs/design/meeting-parts.md, MeetingPart).
  # The topic, study point, assistant and counsel are encrypted, so their lengths are checked by validations only.
  def change
    create_table :meeting_parts, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :kind, null: false
      t.date :meeting_on, null: false
      t.integer :minutes, null: false
      t.string :setting
      t.text :topic, null: false
      t.string :study_point
      t.string :assistant
      t.text :counsel
      t.timestamps

      t.index %i[ user_id meeting_on ]
      t.check_constraint "kind IN ('starting_a_conversation', 'following_up', 'making_disciples', 'explaining_beliefs_demonstration', " \
                         "'explaining_beliefs_talk', 'talk')", name: "meeting_parts_kind_check"
      t.check_constraint "setting IN ('house_to_house', 'informal_witnessing', 'public_witnessing')", name: "meeting_parts_setting_check"
      t.check_constraint "minutes BETWEEN 1 AND 15", name: "meeting_parts_minutes_check"
    end
  end
end
