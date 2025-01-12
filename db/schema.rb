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

ActiveRecord::Schema[8.0].define(version: 2025_01_11_232936) do
  create_table "dictionary_entries", force: :cascade do |t|
    t.string "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dictionary_entry_tags", force: :cascade do |t|
    t.integer "dictionary_entry_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dictionary_entry_id", "tag_id"], name: "index_unique_tag_on_entry", unique: true
    t.index ["dictionary_entry_id"], name: "index_dictionary_entry_tags_on_dictionary_entry_id"
    t.index ["tag_id"], name: "index_dictionary_entry_tags_on_tag_id"
  end

  create_table "meanings", force: :cascade do |t|
    t.integer "dictionary_entry_id", null: false
    t.string "language", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "source_id"
    t.string "pinyin"
    t.index ["dictionary_entry_id", "language", "text", "pinyin", "source_id"], name: "index_meanings_on_dictionary_entry_source_and_content", unique: true
    t.index ["dictionary_entry_id"], name: "index_meanings_on_dictionary_entry_id"
    t.index ["source_id"], name: "index_meanings_on_source_id"
  end

  create_table "review_logs", force: :cascade do |t|
    t.integer "user_learning_id", null: false
    t.integer "anki_id"
    t.integer "ease", null: false
    t.integer "interval"
    t.integer "time_spent"
    t.integer "factor"
    t.integer "time"
    t.integer "log_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_learning_id"], name: "index_review_logs_on_user_learning_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sources", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.date "date_accessed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.index ["name"], name: "index_tags_on_name"
    t.index ["parent_id", "id"], name: "index_tags_on_parent_and_child", unique: true
    t.index ["parent_id"], name: "index_tags_on_parent_id"
  end

  create_table "user_learnings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "dictionary_entry_id", null: false
    t.string "state", null: false
    t.datetime "next_due"
    t.integer "last_interval"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dictionary_entry_id"], name: "index_user_learnings_on_dictionary_entry_id"
    t.index ["user_id", "dictionary_entry_id"], name: "index_user_learnings_on_user_and_entry", unique: true
    t.index ["user_id"], name: "index_user_learnings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "dictionary_entry_tags", "dictionary_entries"
  add_foreign_key "dictionary_entry_tags", "tags"
  add_foreign_key "meanings", "dictionary_entries"
  add_foreign_key "meanings", "sources"
  add_foreign_key "review_logs", "user_learnings"
  add_foreign_key "sessions", "users"
  add_foreign_key "tags", "tags", column: "parent_id"
  add_foreign_key "user_learnings", "dictionary_entries"
  add_foreign_key "user_learnings", "users"
end
