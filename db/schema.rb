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

ActiveRecord::Schema[8.1].define(version: 2026_11_18_030000) do
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

  create_table "ai_acceptances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.integer "version", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "version"], name: "index_ai_acceptances_on_user_id_and_version", unique: true
  end

  create_table "ai_uses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "purpose", null: false
    t.uuid "question_id"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_ai_uses_on_created_at"
    t.index ["question_id"], name: "index_ai_uses_on_question_id", unique: true
    t.index ["user_id", "purpose", "created_at"], name: "index_ai_uses_on_user_id_and_purpose_and_created_at"
    t.check_constraint "purpose::text = ANY (ARRAY['family_study_draft'::character varying, 'personal_study'::character varying]::text[])", name: "ai_uses_purpose_check"
  end

  create_table "bookmarks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "url"
    t.string "scripture"
    t.string "title"
    t.string "comment"
    t.uuid "collection_id"
    t.string "source_type"
    t.uuid "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_bookmarks_on_collection_id"
    t.index ["source_type", "source_id"], name: "index_bookmarks_on_source"
    t.index ["user_id", "created_at"], name: "index_bookmarks_on_user_id_and_created_at"
    t.index ["user_id", "scripture"], name: "index_bookmarks_on_user_id_and_scripture", unique: true
    t.index ["user_id", "url"], name: "index_bookmarks_on_user_id_and_url", unique: true
    t.check_constraint "num_nonnulls(source_type, source_id) <> 1", name: "bookmarks_source_together_check"
    t.check_constraint "num_nonnulls(url, scripture) = 1", name: "bookmarks_page_or_scripture_check"
    t.check_constraint "scripture::text ~ '^\\d+:\\d+(:\\d+(-\\d+)?)?$'::text", name: "bookmarks_scripture_check"
    t.check_constraint "source_type::text = ANY (ARRAY['PersonalStudy'::character varying, 'PersonalNote'::character varying]::text[])", name: "bookmarks_source_type_check"
    t.check_constraint "url::text ~ '^https://(www\\.)?(jw\\.org|wol\\.jw\\.org)/'::text", name: "bookmarks_url_check"
  end

  create_table "chats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ruby_llm_model_id", null: false
    t.uuid "user_id", null: false
    t.uuid "household_id"
    t.string "purpose", null: false
    t.boolean "cancelled", default: false, null: false
    t.string "claim_token"
    t.datetime "claimed_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claimed_until"], name: "index_chats_on_claimed_until", where: "(claim_token IS NOT NULL)"
    t.index ["created_at"], name: "index_chats_on_created_at"
    t.index ["household_id"], name: "index_chats_on_household_id"
    t.index ["ruby_llm_model_id"], name: "index_chats_on_ruby_llm_model_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
    t.check_constraint "purpose::text = ANY (ARRAY['family_study_draft'::character varying, 'personal_study'::character varying]::text[])", name: "chats_purpose_check"
  end

  create_table "collections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.string "used_in", default: "both", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_collections_on_user_id_and_name", unique: true
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 40", name: "collections_name_length_check"
    t.check_constraint "used_in::text = ANY (ARRAY['both'::character varying, 'studies'::character varying, 'notes'::character varying]::text[])", name: "collections_used_in_check"
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

  create_table "family_study_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "household_id", null: false
    t.uuid "user_id", null: false
    t.uuid "chat_id", null: false
    t.text "prompt", null: false
    t.integer "length_minutes", null: false
    t.boolean "young_children", default: false, null: false
    t.string "status", default: "drafting", null: false
    t.jsonb "outline"
    t.jsonb "sources", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_family_study_drafts_on_chat_id", unique: true
    t.index ["household_id", "created_at"], name: "index_family_study_drafts_on_household_id_and_created_at"
    t.index ["user_id"], name: "index_family_study_drafts_on_user_id"
    t.check_constraint "length_minutes = ANY (ARRAY[30, 45, 60])", name: "family_study_drafts_length_minutes_check"
    t.check_constraint "status::text = ANY (ARRAY['drafting'::character varying, 'drafted'::character varying, 'off_topic'::character varying, 'flagged'::character varying, 'failed'::character varying, 'stopped'::character varying, 'discarded'::character varying]::text[])", name: "family_study_drafts_status_check"
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

  create_table "household_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "household_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.date "starts_on", null: false
    t.integer "days", limit: 2, default: 1, null: false
    t.time "time_of_day"
    t.integer "duration_minutes"
    t.string "frequency", default: "once", null: false
    t.integer "interval", default: 1, null: false
    t.integer "week_of_month", limit: 2
    t.date "repeats_until"
    t.string "location"
    t.string "note"
    t.uuid "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_household_events_on_created_by_id"
    t.index ["household_id"], name: "index_household_events_on_household_id"
    t.check_constraint "(time_of_day IS NULL) = (duration_minutes IS NULL)", name: "household_events_timed_duration_check"
    t.check_constraint "\"interval\" > 0", name: "household_events_interval_check"
    t.check_constraint "char_length(location::text) <= 120", name: "household_events_location_length_check"
    t.check_constraint "char_length(title::text) >= 1 AND char_length(title::text) <= 80", name: "household_events_title_length_check"
    t.check_constraint "days = 1 OR time_of_day IS NULL AND frequency::text = 'once'::text", name: "household_events_several_days_check"
    t.check_constraint "days >= 1 AND days <= 14", name: "household_events_days_check"
    t.check_constraint "duration_minutes > 0 AND duration_minutes <= 720", name: "household_events_duration_minutes_check"
    t.check_constraint "frequency::text <> 'monthly'::text OR week_of_month IS NOT NULL", name: "household_events_monthly_week_of_month_check"
    t.check_constraint "frequency::text = ANY (ARRAY['once'::character varying, 'weekly'::character varying, 'monthly'::character varying]::text[])", name: "household_events_frequency_check"
    t.check_constraint "kind::text = ANY (ARRAY['circuit_assembly'::character varying, 'regional_convention'::character varying, 'co_visit'::character varying, 'memorial'::character varying, 'field_service'::character varying, 'other'::character varying]::text[])", name: "household_events_kind_check"
    t.check_constraint "week_of_month = ANY (ARRAY[1, 2, 3, 4, 5, '-1'::integer])", name: "household_events_week_of_month_check"
  end

  create_table "household_meeting_helpers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "household_id", null: false
    t.uuid "enabled_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled_by_id"], name: "index_household_meeting_helpers_on_enabled_by_id"
    t.index ["household_id"], name: "index_household_meeting_helpers_on_household_id", unique: true
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

  create_table "meeting_note_drawings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_note_id", null: false
    t.string "step", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_note_id", "step"], name: "index_meeting_note_drawings_on_meeting_note_id_and_step", unique: true
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

  create_table "meeting_note_marks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_note_id", null: false
    t.string "step", null: false
    t.datetime "created_at", null: false
    t.index ["meeting_note_id", "step"], name: "index_meeting_note_marks_on_meeting_note_id_and_step", unique: true
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

  create_table "membership_study_ai_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "membership_id", null: false
    t.uuid "granted_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_by_id"], name: "index_membership_study_ai_grants_on_granted_by_id"
    t.index ["membership_id"], name: "index_membership_study_ai_grants_on_membership_id", unique: true
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

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "chat_id", null: false
    t.string "role", null: false
    t.text "content"
    t.boolean "cache_until_here", default: false, null: false
    t.string "cache_ttl"
    t.text "thinking_text"
    t.text "thinking_signature"
    t.string "phase"
    t.text "continuation"
    t.string "finish_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "personal_note_pins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "personal_note_id", null: false
    t.datetime "created_at", null: false
    t.index ["personal_note_id"], name: "index_personal_note_pins_on_personal_note_id", unique: true
  end

  create_table "personal_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "collection_id"
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color", default: "none", null: false
    t.index ["collection_id"], name: "index_personal_notes_on_collection_id"
    t.index ["user_id"], name: "index_personal_notes_on_user_id"
    t.check_constraint "char_length(title::text) >= 1 AND char_length(title::text) <= 120", name: "personal_notes_title_length_check"
    t.check_constraint "color::text = ANY (ARRAY['none'::character varying, 'yellow'::character varying, 'green'::character varying, 'blue'::character varying, 'purple'::character varying, 'pink'::character varying, 'orange'::character varying]::text[])", name: "personal_notes_color_check"
  end

  create_table "personal_studies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "collection_id"
    t.string "title", null: false
    t.datetime "last_asked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "chat_id", null: false
    t.index ["chat_id"], name: "index_personal_studies_on_chat_id", unique: true
    t.index ["collection_id"], name: "index_personal_studies_on_collection_id"
    t.index ["user_id"], name: "index_personal_studies_on_user_id"
    t.check_constraint "char_length(title::text) >= 1 AND char_length(title::text) <= 120", name: "personal_studies_title_length_check"
  end

  create_table "personal_study_questions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "personal_study_id", null: false
    t.uuid "user_id", null: false
    t.text "prompt", null: false
    t.boolean "young_reader", default: false, null: false
    t.string "status", default: "asking", null: false
    t.jsonb "answer"
    t.jsonb "sources", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["personal_study_id", "created_at"], name: "index_personal_study_questions_on_study_and_created_at"
    t.index ["user_id"], name: "index_personal_study_questions_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['asking'::character varying, 'answered'::character varying, 'off_topic'::character varying, 'flagged'::character varying, 'failed'::character varying, 'stopped'::character varying]::text[])", name: "personal_study_questions_status_check"
  end

  create_table "personal_time_completions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "personal_time_id", null: false
    t.date "on", null: false
    t.datetime "created_at", null: false
    t.index ["personal_time_id", "on"], name: "index_personal_time_completions_on_personal_time_id_and_on", unique: true
  end

  create_table "personal_times", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.integer "wdays", limit: 2, null: false, array: true
    t.time "time_of_day", null: false
    t.integer "duration_minutes", default: 30, null: false
    t.date "starts_on", default: -> { "CURRENT_DATE" }, null: false
    t.string "opens_type"
    t.uuid "opens_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["opens_type", "opens_id"], name: "index_personal_times_on_opens_type_and_opens_id"
    t.index ["user_id"], name: "index_personal_times_on_user_id"
    t.check_constraint "(opens_type IS NULL) = (opens_id IS NULL)", name: "personal_times_opens_check"
    t.check_constraint "cardinality(wdays) >= 1 AND cardinality(wdays) <= 7 AND wdays <@ '{0,1,2,3,4,5,6}'::smallint[]", name: "personal_times_wdays_check"
    t.check_constraint "duration_minutes >= 5 AND duration_minutes <= 240", name: "personal_times_duration_minutes_check"
    t.check_constraint "kind::text = ANY (ARRAY['bible_reading'::character varying, 'personal_study'::character varying, 'meeting_prep'::character varying, 'other'::character varying]::text[])", name: "personal_times_kind_check"
    t.check_constraint "opens_type::text = ANY (ARRAY['PersonalStudy'::character varying, 'PersonalNote'::character varying]::text[])", name: "personal_times_opens_type_check"
  end

  create_table "ruby_llm_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "provider_batch_id", null: false
    t.string "provider", null: false
    t.string "status", null: false
    t.string "raw_status"
    t.boolean "completed", default: false, null: false
    t.string "chat_type"
    t.string "batch_protocol"
    t.jsonb "chat_ids", default: []
    t.jsonb "request_counts"
    t.jsonb "reported_cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_chat_files", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "chat_type", null: false
    t.uuid "chat_id", null: false
    t.string "owner_type"
    t.uuid "owner_id"
    t.string "path", null: false
    t.string "content_type"
    t.bigint "byte_size"
    t.string "digest"
    t.text "text"
    t.string "read_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id", "path"], name: "index_ruby_llm_chat_files_on_chat_type_and_chat_id_and_path"
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_chat_files_on_owner_type_and_owner_id"
  end

  create_table "ruby_llm_mcp_credentials", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "owner_type"
    t.uuid "owner_id"
    t.string "key", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_ruby_llm_mcp_credentials_on_key", unique: true
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_mcp_credentials_on_owner"
  end

  create_table "ruby_llm_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "model_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "family"
    t.datetime "model_created_at"
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.date "knowledge_cutoff"
    t.datetime "unlisted_at"
    t.jsonb "modalities", default: {}
    t.jsonb "capabilities", default: []
    t.jsonb "pricing", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_ruby_llm_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["modalities"], name: "index_ruby_llm_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_provider_files", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "blob_key", null: false
    t.string "provider", null: false
    t.string "account", null: false
    t.text "file_id", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_key", "provider", "account"], name: "index_ruby_llm_provider_files_uniqueness", unique: true
  end

  create_table "ruby_llm_queued_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "chat_type", null: false
    t.uuid "chat_id", null: false
    t.string "sender_type"
    t.uuid "sender_id"
    t.text "content"
    t.boolean "steer", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_queued_messages_on_chat_type_and_chat_id"
    t.index ["sender_type", "sender_id"], name: "index_ruby_llm_queued_messages_on_sender_type_and_sender_id"
  end

  create_table "ruby_llm_tool_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "message_type", null: false
    t.uuid "message_id", null: false
    t.string "result_type"
    t.uuid "result_id"
    t.string "tool_call_id", null: false
    t.string "provider_call_id"
    t.string "namespace"
    t.string "name", null: false
    t.text "thought_signature"
    t.string "approval"
    t.boolean "remote", default: false, null: false
    t.datetime "claimed_until"
    t.jsonb "arguments", default: {}
    t.jsonb "mcp_state"
    t.jsonb "mcp_result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "chat_type"
    t.uuid "chat_id"
    t.string "message_type"
    t.uuid "message_id"
    t.string "owner_type"
    t.uuid "owner_id"
    t.string "operation", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "status", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "cache_read_tokens"
    t.integer "cache_write_tokens"
    t.integer "thinking_tokens"
    t.integer "characters"
    t.decimal "audio_seconds", precision: 16, scale: 6
    t.integer "search_units"
    t.jsonb "server_tool_use"
    t.decimal "input_cost", precision: 16, scale: 10
    t.decimal "output_cost", precision: 16, scale: 10
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.decimal "characters_cost", precision: 16, scale: 10
    t.decimal "audio_seconds_cost", precision: 16, scale: 10
    t.decimal "search_units_cost", precision: 16, scale: 10
    t.decimal "total_cost", precision: 16, scale: 10
    t.string "workflow_id"
    t.string "workflow_name"
    t.string "workflow_step_id"
    t.string "workflow_step_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_usages_on_owner_type_and_owner_id"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.index ["workflow_id"], name: "index_ruby_llm_usages_on_workflow_id"
    t.check_constraint "operation::text = ANY (ARRAY['chat'::text, 'embedding'::text, 'moderation'::text, 'image'::text, 'speech'::text, 'transcription'::text, 'ocr'::text, 'rerank'::text, 'judgment'::text, 'video'::text, 'research'::text, 'code_execution'::text])"
    t.check_constraint "status::text = ANY (ARRAY['pending'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text])"
  end

  create_table "taggings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tag_id", null: false
    t.string "taggable_type", null: false
    t.uuid "taggable_id", null: false
    t.datetime "created_at", null: false
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_taggings_on_tag_id_and_taggable_type_and_taggable_id", unique: true
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
    t.check_constraint "taggable_type::text = ANY (ARRAY['MeetingNote'::character varying, 'Goal'::character varying, 'PersonalStudy'::character varying, 'PersonalNote'::character varying, 'Bookmark'::character varying]::text[])", name: "taggings_taggable_type_check"
  end

  create_table "tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.check_constraint "name::text ~ '^[a-z0-9][a-z0-9-]{0,29}$'::text", name: "tags_name_check"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "time_zone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "appearance", default: "auto", null: false
    t.check_constraint "appearance::text = ANY (ARRAY['auto'::character varying, 'light'::character varying, 'dark'::character varying]::text[])", name: "users_appearance_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_acceptances", "users"
  add_foreign_key "ai_uses", "personal_study_questions", column: "question_id", on_delete: :nullify
  add_foreign_key "ai_uses", "users"
  add_foreign_key "bookmarks", "collections", on_delete: :nullify
  add_foreign_key "bookmarks", "users"
  add_foreign_key "chats", "households"
  add_foreign_key "chats", "ruby_llm_models"
  add_foreign_key "chats", "users"
  add_foreign_key "collections", "users"
  add_foreign_key "family_studies", "households"
  add_foreign_key "family_studies", "users", column: "default_conductor_id"
  add_foreign_key "family_study_drafts", "chats", on_delete: :cascade
  add_foreign_key "family_study_drafts", "households"
  add_foreign_key "family_study_drafts", "users"
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
  add_foreign_key "household_events", "households"
  add_foreign_key "household_events", "users", column: "created_by_id"
  add_foreign_key "household_meeting_helpers", "households", on_delete: :cascade
  add_foreign_key "household_meeting_helpers", "users", column: "enabled_by_id"
  add_foreign_key "identities", "users"
  add_foreign_key "invitations", "households", on_delete: :cascade
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "meeting_note_drawings", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_note_gems", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_note_marks", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_note_parts", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_note_sharings", "households", on_delete: :cascade
  add_foreign_key "meeting_note_sharings", "meeting_notes", on_delete: :cascade
  add_foreign_key "meeting_notes", "users"
  add_foreign_key "membership_study_ai_grants", "memberships", on_delete: :cascade
  add_foreign_key "membership_study_ai_grants", "users", column: "granted_by_id", on_delete: :cascade
  add_foreign_key "memberships", "households"
  add_foreign_key "memberships", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "personal_note_pins", "personal_notes", on_delete: :cascade
  add_foreign_key "personal_notes", "collections", on_delete: :nullify
  add_foreign_key "personal_notes", "users"
  add_foreign_key "personal_studies", "chats"
  add_foreign_key "personal_studies", "collections", on_delete: :nullify
  add_foreign_key "personal_studies", "users"
  add_foreign_key "personal_study_questions", "personal_studies", on_delete: :cascade
  add_foreign_key "personal_study_questions", "users"
  add_foreign_key "personal_time_completions", "personal_times", on_delete: :cascade
  add_foreign_key "personal_times", "users"
  add_foreign_key "taggings", "tags", on_delete: :cascade
  add_foreign_key "tags", "users"
end
