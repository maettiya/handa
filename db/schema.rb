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

ActiveRecord::Schema[7.1].define(version: 2026_01_26_024242) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
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

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.string "title"
    t.string "original_filename"
    t.bigint "user_id", null: false
    t.bigint "parent_id"
    t.string "path"
    t.bigint "file_size"
    t.boolean "is_directory", default: false
    t.boolean "hidden", default: false
    t.string "file_type"
    t.string "asset_type"
    t.boolean "extracted", default: false
    t.boolean "ephemeral", default: false, null: false
    t.bigint "shared_from_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "processing_status"
    t.integer "processing_progress", default: 0
    t.integer "processing_total", default: 0
    t.index ["parent_id"], name: "index_assets_on_parent_id"
    t.index ["shared_from_user_id"], name: "index_assets_on_shared_from_user_id"
    t.index ["user_id", "ephemeral"], name: "index_assets_on_user_id_and_ephemeral"
    t.index ["user_id", "parent_id"], name: "index_assets_on_user_id_and_parent_id"
    t.index ["user_id"], name: "index_assets_on_user_id"
  end

  create_table "collaborations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "collaborator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collaborator_id"], name: "index_collaborations_on_collaborator_id"
    t.index ["user_id", "collaborator_id"], name: "index_collaborations_on_user_id_and_collaborator_id", unique: true
    t.index ["user_id"], name: "index_collaborations_on_user_id"
  end

  create_table "downloads", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "asset_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "progress", default: 0
    t.integer "total", default: 0
    t.string "filename"
    t.string "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_downloads_on_asset_id"
    t.index ["user_id", "status"], name: "index_downloads_on_user_id_and_status"
    t.index ["user_id"], name: "index_downloads_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id", null: false
    t.string "notification_type", null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "project_files", force: :cascade do |t|
    t.string "file_type"
    t.string "original_filename"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "path"
    t.bigint "file_size"
    t.boolean "is_directory", default: false
    t.boolean "hidden", default: false
    t.bigint "parent_id"
    t.index ["parent_id"], name: "index_project_files_on_parent_id"
    t.index ["project_id"], name: "index_project_files_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "project_type"
    t.boolean "extracted", default: false
    t.boolean "ephemeral", default: false, null: false
    t.bigint "shared_from_user_id"
    t.index ["shared_from_user_id"], name: "index_projects_on_shared_from_user_id"
    t.index ["user_id", "ephemeral"], name: "index_projects_on_user_id_and_ephemeral"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "share_links", force: :cascade do |t|
    t.string "token"
    t.datetime "expires_at"
    t.integer "download_count"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "asset_id", null: false
    t.index ["asset_id"], name: "index_share_links_on_asset_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assets", "assets", column: "parent_id"
  add_foreign_key "assets", "users"
  add_foreign_key "assets", "users", column: "shared_from_user_id"
  add_foreign_key "collaborations", "users"
  add_foreign_key "collaborations", "users", column: "collaborator_id"
  add_foreign_key "downloads", "assets"
  add_foreign_key "downloads", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "project_files", "project_files", column: "parent_id"
  add_foreign_key "project_files", "projects"
  add_foreign_key "projects", "users"
  add_foreign_key "projects", "users", column: "shared_from_user_id"
  add_foreign_key "share_links", "assets"
end
