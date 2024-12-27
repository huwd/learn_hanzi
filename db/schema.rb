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

ActiveRecord::Schema[8.0].define(version: 2024_12_27_184441) do
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
    t.index ["dictionary_entry_id"], name: "index_meanings_on_dictionary_entry_id"
    t.index ["source_id"], name: "index_meanings_on_source_id"
    t.index ["text", "language", "source_id", "pinyin"], name: "index_meanings_on_text_language_source_pinyin", unique: true
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
    t.index ["parent_id"], name: "index_tags_on_parent_id"
  end

  add_foreign_key "dictionary_entry_tags", "dictionary_entries"
  add_foreign_key "dictionary_entry_tags", "tags"
  add_foreign_key "meanings", "dictionary_entries"
  add_foreign_key "meanings", "sources"
  add_foreign_key "tags", "tags", column: "parent_id"
end
