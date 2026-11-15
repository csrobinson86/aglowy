# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_15_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "action_text_rich_texts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "family_studies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "household_id", null: false
    t.string "frequency", default: "once", null: false
    t.integer "interval", default: 1, null: false
    t.date "starts_on", null: false
    t.integer "week_of_month", limit: 2
    t.time "time_of_day", null: false
    t.integer "duration_minutes", default: 60, null: false
    t.date "ends_on"
    t.uuid "default_conductor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["default_conductor_id"], name: "index_family_studies_on_default_conductor_id"
    t.index ["household_id"], name: "index_family_studies_on_household_id"
    t.check_constraint "\"interval\" > 0", name: "family_studies_interval_check"
    t.check_constraint "duration_minutes > 0", name: "family_studies_duration_minutes_check"
    t.check_constraint "frequency::text <> 'monthly'::text OR week_of_month IS NOT NULL", name: "family_studies_monthly_week_of_month_check"
    t.check_constraint "frequency::text = ANY (ARRAY['once'::character varying, 'daily'::character varying, 'weekly'::character varying, 'monthly'::character varying]::text[])", name: "family_studies_frequency_check"
    t.check_constraint "week_of_month = ANY (ARRAY[1, 2, 3, 4, 5, '-1'::integer])", name: "family_studies_week_of_month_check"
  end

  create_table "family_study_resources", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "session_id", null: false
    t.string "kind", null: false
    t.string "url"
    t.string "title", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_family_study_resources_on_session_id"
    t.check_constraint "kind::text <> 'link'::text OR url IS NOT NULL AND url::text ~* '^https?://'::text", name: "family_study_resources_url_check"
    t.check_constraint "kind::text = ANY (ARRAY['link'::character varying, 'file'::character varying]::text[])", name: "family_study_resources_kind_check"
  end

  create_table "family_study_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "family_study_id", null: false
    t.datetime "recurrence_at", null: false
    t.datetime "scheduled_at", null: false
    t.string "topic"
    t.uuid "conductor_id"
    t.datetime "detached_at"
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conductor_id"], name: "index_family_study_sessions_on_conductor_id"
    t.index ["family_study_id", "recurrence_at"], name: "index_family_study_sessions_on_study_and_recurrence_at", unique: true
    t.index ["scheduled_at"], name: "index_family_study_sessions_on_scheduled_at"
  end

  create_table "goal_archivals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "goal_id", null: false
    t.uuid "archived_by_id", null: false
    t.datetime "created_at", null: false
    t.index ["archived_by_id"], name: "index_goal_archivals_on_archived_by_id"
    t.index ["goal_id"], name: "index_goal_archivals_on_goal_id", unique: true
  end

  create_table "goal_completions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "goal_id", null: false
    t.uuid "completed_by_id", null: false
    t.datetime "created_at", null: false
    t.index ["completed_by_id"], name: "index_goal_completions_on_completed_by_id"
    t.index ["goal_id"], name: "index_goal_completions_on_goal_id", unique: true
  end

  create_table "goal_sharings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "goal_id", null: false
    t.uuid "household_id", null: false
    t.datetime "created_at", null: false
    t.index ["goal_id", "household_id"], name: "index_goal_sharings_on_goal_id_and_household_id", unique: true
    t.index ["household_id"], name: "index_goal_sharings_on_household_id"
  end

  create_table "goal_step_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "step_id", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.index ["step_id", "user_id"], name: "index_goal_step_assignments_on_step_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_goal_step_assignments_on_user_id"
  end

  create_table "goal_step_completions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "step_id", null: false
    t.uuid "user_id"
    t.uuid "completed_by_id", null: false
    t.datetime "created_at", null: false
    t.index ["completed_by_id"], name: "index_goal_step_completions_on_completed_by_id"
    t.index ["step_id", "user_id"], name: "index_goal_step_completions_on_step_id_and_user_id", unique: true, nulls_not_distinct: true
    t.index ["user_id"], name: "index_goal_step_completions_on_user_id"
  end

  create_table "goal_steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "goal_id", null: false
    t.string "title", null: false
    t.date "due_on"
    t.integer "position", null: false
    t.uuid "family_study_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_study_id"], name: "index_goal_steps_on_family_study_id"
    t.index ["goal_id", "position"], name: "index_goal_steps_on_goal_id_and_position"
  end

  create_table "goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "household_id"
    t.uuid "user_id"
    t.uuid "set_by_id", null: false
    t.string "kind", default: "milestone", null: false
    t.string "title", null: false
    t.text "body"
    t.date "target_on", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_goals_on_household_id"
    t.index ["set_by_id"], name: "index_goals_on_set_by_id"
    t.index ["user_id"], name: "index_goals_on_user_id"
    t.check_constraint "kind::text = 'milestone'::text", name: "goals_kind_check"
    t.check_constraint "num_nonnulls(household_id, user_id) = 1", name: "goals_one_owner_check"
  end

  create_table "households", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "time_zone", default: "UTC", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "midweek_meeting_wday", limit: 2
    t.time "midweek_meeting_time"
    t.integer "weekend_meeting_wday", limit: 2
    t.time "weekend_meeting_time"
    t.check_constraint "midweek_meeting_wday >= 0 AND midweek_meeting_wday <= 6", name: "households_midweek_meeting_wday_check"
    t.check_constraint "num_nulls(midweek_meeting_wday, midweek_meeting_time, weekend_meeting_wday, weekend_meeting_time) = ANY (ARRAY[0, 4])", name: "households_meeting_times_check"
    t.check_constraint "weekend_meeting_wday >= 0 AND weekend_meeting_wday <= 6", name: "households_weekend_meeting_wday_check"
  end

  create_table "identities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.boolean "staff", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index "lower((username)::text)", name: "index_identities_on_lower_username", unique: true
    t.index ["confirmation_token"], name: "index_identities_on_confirmation_token", unique: true
    t.index ["email"], name: "index_identities_on_email", unique: true
    t.index ["reset_password_token"], name: "index_identities_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_identities_on_unlock_token", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id", unique: true
    t.check_constraint "email::text <> ''::text", name: "identities_email_not_blank_check"
    t.check_constraint "num_nonnulls(email, username) >= 1", name: "identities_email_or_username_check"
    t.check_constraint "username::text ~ '^[a-z0-9][a-z0-9.-]{2,29}$'::text", name: "identities_username_format_check"
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "household_id", null: false
    t.string "email", null: false
    t.string "role", default: "adult", null: false
    t.uuid "invited_by_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "email"], name: "index_invitations_on_household_id_and_email", unique: true
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.check_constraint "role::text = ANY (ARRAY['adult'::character varying, 'head'::character varying]::text[])", name: "invitations_role_check"
  end

  create_table "meeting_note_gems", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_note_id", null: false
    t.string "scripture", null: false
    t.integer "book_number", limit: 2, null: false
    t.integer "chapter", limit: 2, null: false
    t.integer "verse_start", limit: 2
    t.integer "verse_end", limit: 2
    t.text "insight"
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_note_id"], name: "index_meeting_note_gems_on_meeting_note_id"
    t.check_constraint "book_number >= 1 AND book_number <= 66", name: "meeting_note_gems_book_number_check"
    t.check_constraint "chapter > 0", name: "meeting_note_gems_chapter_check"
    t.check_constraint "verse_start IS NULL AND verse_end IS NULL OR verse_start IS NOT NULL AND verse_end IS NOT NULL AND verse_start > 0 AND verse_end >= verse_start", name: "meeting_note_gems_verses_check"
  end

  create_table "meeting_note_parts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_note_id", null: false
    t.string "key", null: false
    t.string "title"
    t.string "speaker"
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_note_id", "key"], name: "index_meeting_note_parts_on_note_and_key_once", unique: true, where: "((key)::text <> 'living_part'::text)"
    t.index ["meeting_note_id"], name: "index_meeting_note_parts_on_meeting_note_id"
  end

  create_table "meeting_note_sharings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_note_id", null: false
    t.uuid "household_id", null: false
    t.datetime "created_at", null: false
    t.index ["household_id"], name: "index_meeting_note_sharings_on_household_id"
    t.index ["meeting_note_id", "household_id"], name: "index_meeting_note_sharings_on_note_and_household", unique: true
  end

  create_table "meeting_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "kind", null: false
    t.date "week_of", null: false
    t.integer "outline_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "kind", "week_of"], name: "index_meeting_notes_on_user_id_and_kind_and_week_of", unique: true
    t.check_constraint "EXTRACT(isodow FROM week_of) = 1::numeric", name: "meeting_notes_week_of_monday_check"
    t.check_constraint "kind::text = ANY (ARRAY['midweek'::character varying, 'weekend'::character varying]::text[])", name: "meeting_notes_kind_check"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "household_id", null: false
    t.uuid "user_id", null: false
    t.string "role", default: "adult", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "role"], name: "index_memberships_on_household_id_and_role"
    t.index ["household_id", "user_id"], name: "index_memberships_on_household_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['head'::character varying, 'adult'::character varying, 'child'::character varying]::text[])", name: "memberships_role_check"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "time_zone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "family_studies", "households"
  add_foreign_key "family_studies", "users", column: "default_conductor_id"
  add_foreign_key "family_study_resources", "family_study_sessions", column: "session_id"
  add_foreign_key "family_study_sessions", "family_studies"
  add_foreign_key "family_study_sessions", "users", column: "conductor_id"
  add_foreign_key "goal_archivals", "goals", on_delete: :cascade
  add_foreign_key "goal_archivals", "users", column: "archived_by_id"
  add_foreign_key "goal_completions", "goals", on_delete: :cascade
  add_foreign_key "goal_completions", "users", column: "completed_by_id"
  add_foreign_key "goal_sharings", "goals", on_delete: :cascade
  add_foreign_key "goal_sharings", "households", on_delete: :cascade
  add_foreign_key "goal_step_assignments", "goal_steps", column: "step_id", on_delete: :cascade
  add_foreign_key "goal_step_assignments", "users", on_delete: :cascade
  add_foreign_key "goal_step_completions", "goal_steps", column: "step_id", on_delete: :cascade
  add_foreign_key "goal_step_completions", "users", column: "completed_by_id"
  add_foreign_key "goal_step_completions", "users", on_delete: :cascade
  add_foreign_key "goal_steps", "family_studies", on_delete: :nullify
  add_foreign_key "goal_steps", "goals", on_delete: :cascade
  add_foreign_key "goals", "households", on_delete: :cascade
  add_foreign_key "goals", "users", column: "set_by_id"
  add_foreign_key "goals", "users", on_delete: :cascade
  add_foreign_key "identities", "users"
  add_foreign_key "invitations", "households", on_delete: :cascade
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "meeting_note_gems", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_note_parts", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_note_sharings", "households", on_delete: :cascade
  add_foreign_key "meeting_note_sharings", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_notes", "users"
  add_foreign_key "memberships", "households"
  add_foreign_key "memberships", "users"
end
