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

ActiveRecord::Schema[8.1].define(version: 2026_11_14_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

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

  create_table "households", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "time_zone", default: "UTC", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "identities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "email", default: "", null: false
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
    t.index ["confirmation_token"], name: "index_identities_on_confirmation_token", unique: true
    t.index ["email"], name: "index_identities_on_email", unique: true
    t.index ["reset_password_token"], name: "index_identities_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_identities_on_unlock_token", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id", unique: true
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

  add_foreign_key "family_studies", "households"
  add_foreign_key "family_studies", "users", column: "default_conductor_id"
  add_foreign_key "family_study_sessions", "family_studies"
  add_foreign_key "family_study_sessions", "users", column: "conductor_id"
  add_foreign_key "identities", "users"
  add_foreign_key "memberships", "households"
  add_foreign_key "memberships", "users"
end
