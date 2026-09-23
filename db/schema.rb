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

ActiveRecord::Schema[7.2].define(version: 2026_09_23_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "assignments", force: :cascade do |t|
    t.bigint "subject_id"
    t.string "title"
    t.date "due_on"
    t.text "notes"
    t.string "status", default: "pending", null: false
    t.datetime "registered_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "classroom_id"
    t.integer "tower_cycle", default: 1, null: false
    t.index ["classroom_id"], name: "index_assignments_on_classroom_id"
    t.index ["status"], name: "index_assignments_on_status"
    t.index ["subject_id"], name: "index_assignments_on_subject_id"
    t.index ["user_id"], name: "index_assignments_on_user_id"
  end

  create_table "board", primary_key: "board_id", force: :cascade do |t|
    t.integer "board_user_id"
    t.string "board_name"
    t.boolean "board_is_public"
    t.datetime "timestamp"
  end

  create_table "board_share", primary_key: "board_share_id", force: :cascade do |t|
    t.integer "share_board_id"
    t.integer "share_user_id"
  end

  create_table "board_slides", force: :cascade do |t|
    t.integer "board_id", null: false
    t.integer "position", null: false
    t.text "content", default: "{\"refs\":[],\"notes\":[],\"strokes\":[]}", null: false
    t.index ["board_id", "position"], name: "index_board_slides_on_board_id_and_position"
  end

  create_table "boardrelate", primary_key: "boardrelate_id", force: :cascade do |t|
    t.integer "relate_board_id"
    t.integer "relate_board_reference_id"
    t.string "ralate_borad_text"
    t.integer "relate_board_position"
  end

  create_table "classrooms", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.string "name", null: false
    t.string "join_code", null: false
    t.integer "tower_cycle", default: 1, null: false
    t.datetime "last_collapsed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["join_code"], name: "index_classrooms_on_join_code", unique: true
    t.index ["school_id"], name: "index_classrooms_on_school_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "classroom_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_memberships_on_classroom_id"
    t.index ["user_id", "classroom_id"], name: "index_memberships_on_user_id_and_classroom_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "reference", primary_key: "reference_id", force: :cascade do |t|
    t.integer "reference_user_id"
    t.string "reference_url"
    t.string "reference_imageurl"
    t.string "reference_text"
    t.string "reference_start_time"
    t.string "reference_end_time"
    t.string "timestamp"
    t.string "reference_title"
  end

  create_table "reference_share", primary_key: "reference_share_id", force: :cascade do |t|
    t.integer "share_reference_id"
    t.integer "share_user_id"
  end

  create_table "schools", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subjects", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#5b6cff", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "timetable_slots", force: :cascade do |t|
    t.bigint "subject_id", null: false
    t.integer "weekday", null: false
    t.integer "period", null: false
    t.time "starts_at", null: false
    t.time "ends_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["subject_id"], name: "index_timetable_slots_on_subject_id"
    t.index ["user_id"], name: "index_timetable_slots_on_user_id"
    t.index ["weekday", "starts_at", "ends_at"], name: "index_timetable_slots_on_weekday_and_starts_at_and_ends_at"
  end

  create_table "user", primary_key: "user_id", force: :cascade do |t|
    t.string "user_name"
    t.string "user_iconurl"
    t.string "password_digest"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "assignments", "classrooms"
  add_foreign_key "assignments", "subjects"
  add_foreign_key "assignments", "users"
  add_foreign_key "classrooms", "schools"
  add_foreign_key "memberships", "classrooms"
  add_foreign_key "memberships", "users"
  add_foreign_key "timetable_slots", "subjects"
  add_foreign_key "timetable_slots", "users"
end
