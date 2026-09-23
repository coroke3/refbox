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

ActiveRecord::Schema[7.2].define(version: 7) do
  create_table "board", primary_key: "board_id", force: :cascade do |t|
    t.integer "board_user_id", null: false
    t.string "board_name", null: false
    t.boolean "board_is_public", default: false, null: false
    t.datetime "timestamp", null: false
    t.index ["board_user_id"], name: "index_board_on_board_user_id"
  end

  create_table "board_share", primary_key: "board_share_id", force: :cascade do |t|
    t.integer "share_board_id", null: false
    t.integer "share_user_id", null: false
    t.index ["share_board_id", "share_user_id"], name: "index_board_share_unique", unique: true
  end

  create_table "board_slides", force: :cascade do |t|
    t.integer "board_id", null: false
    t.integer "position", null: false
    t.text "content", default: "{\"refs\":[],\"notes\":[],\"strokes\":[]}", null: false
    t.index ["board_id", "position"], name: "index_board_slides_on_board_id_and_position"
  end

  create_table "boardrelate", primary_key: "boardrelate_id", force: :cascade do |t|
    t.integer "relate_board_id", null: false
    t.integer "relate_board_reference_id", null: false
    t.text "ralate_borad_text", default: "", null: false
    t.integer "relate_board_position", default: 0, null: false
    t.index ["relate_board_id", "relate_board_reference_id"], name: "index_boardrelate_unique", unique: true
  end

  create_table "reference", primary_key: "reference_id", force: :cascade do |t|
    t.integer "reference_user_id", null: false
    t.string "reference_title", default: "", null: false
    t.string "reference_url", limit: 2000, null: false
    t.string "reference_imageurl", limit: 2000, default: "", null: false
    t.text "reference_text", default: "", null: false
    t.string "reference_start_time", default: "", null: false
    t.string "reference_end_time", default: "", null: false
    t.datetime "timestamp", null: false
    t.index ["reference_user_id"], name: "index_reference_on_reference_user_id"
  end

  create_table "reference_share", primary_key: "reference_share_id", force: :cascade do |t|
    t.integer "share_reference_id", null: false
    t.integer "share_user_id", null: false
    t.index ["share_reference_id", "share_user_id"], name: "index_reference_share_unique", unique: true
  end

  create_table "user", primary_key: "user_id", force: :cascade do |t|
    t.string "user_name", null: false
    t.string "user_iconurl", default: "", null: false
    t.string "password_digest", null: false
    t.index "LOWER(user_name)", name: "index_user_on_lower_name", unique: true
  end

  add_foreign_key "board", "user", column: "board_user_id", primary_key: "user_id"
  add_foreign_key "board_share", "board", column: "share_board_id", primary_key: "board_id"
  add_foreign_key "board_share", "user", column: "share_user_id", primary_key: "user_id"
  add_foreign_key "boardrelate", "board", column: "relate_board_id", primary_key: "board_id"
  add_foreign_key "boardrelate", "reference", column: "relate_board_reference_id", primary_key: "reference_id"
  add_foreign_key "reference", "user", column: "reference_user_id", primary_key: "user_id"
  add_foreign_key "reference_share", "reference", column: "share_reference_id", primary_key: "reference_id"
  add_foreign_key "reference_share", "user", column: "share_user_id", primary_key: "user_id"
end
