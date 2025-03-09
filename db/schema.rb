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

ActiveRecord::Schema[7.1].define(version: 2025_03_09_091052) do
  create_table "addresses", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "address_type"
    t.string "name"
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "city", null: false
    t.string "state"
    t.string "postal_code", null: false
    t.string "country", null: false
    t.string "phone_number"
    t.boolean "is_default", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "logo"
    t.string "website"
    t.string "country_of_origin"
    t.integer "year_established"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_brands_on_name"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "parent_id"
    t.integer "position"
    t.string "slug", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "payment_methods", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "payment_type", null: false
    t.string "provider"
    t.string "account_number"
    t.string "expiry_date"
    t.string "name_on_card"
    t.boolean "is_default", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_payment_methods_on_user_id"
  end

  create_table "price_histories", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "product_variant_id"
    t.decimal "old_price", precision: 10, scale: 2, null: false
    t.decimal "new_price", precision: 10, scale: 2, null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_price_histories_on_product_id"
    t.index ["product_variant_id"], name: "index_price_histories_on_product_variant_id"
  end

  create_table "product_accessories", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "accessory_id", null: false
    t.boolean "is_required", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accessory_id"], name: "index_product_accessories_on_accessory_id"
    t.index ["product_id", "accessory_id"], name: "index_product_accessories_on_product_id_and_accessory_id", unique: true
    t.index ["product_id"], name: "index_product_accessories_on_product_id"
  end

  create_table "product_attributes", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "name", null: false
    t.string "value", null: false
    t.boolean "is_filterable", default: false
    t.boolean "is_searchable", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "name"], name: "index_product_attributes_on_product_id_and_name"
    t.index ["product_id"], name: "index_product_attributes_on_product_id"
  end

  create_table "product_bundle_items", force: :cascade do |t|
    t.integer "product_bundle_id", null: false
    t.integer "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_bundle_id", "product_id"], name: "index_product_bundle_items_on_bundle_and_product", unique: true
    t.index ["product_bundle_id"], name: "index_product_bundle_items_on_product_bundle_id"
    t.index ["product_id"], name: "index_product_bundle_items_on_product_id"
  end

  create_table "product_bundles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "discount_percentage", precision: 5, scale: 2
    t.datetime "start_date"
    t.datetime "end_date"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_product_bundles_on_name"
  end

  create_table "product_descriptions", force: :cascade do |t|
    t.integer "product_id", null: false
    t.text "full_description", null: false
    t.text "features"
    t.text "care_instructions"
    t.text "warranty_info"
    t.text "return_policy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_descriptions_on_product_id"
  end

  create_table "product_documents", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "document_url", null: false
    t.string "title"
    t.string "document_type"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_documents_on_product_id"
  end

  create_table "product_images", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "product_variant_id"
    t.string "image_url", null: false
    t.string "alt_text"
    t.integer "position", default: 0
    t.boolean "is_primary", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_images_on_product_id"
    t.index ["product_variant_id"], name: "index_product_images_on_product_variant_id"
  end

  create_table "product_specifications", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "name", null: false
    t.string "value", null: false
    t.string "unit"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "name"], name: "index_product_specifications_on_product_id_and_name"
    t.index ["product_id"], name: "index_product_specifications_on_product_id"
  end

  create_table "product_tags", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "tag_id"], name: "index_product_tags_on_product_id_and_tag_id", unique: true
    t.index ["product_id"], name: "index_product_tags_on_product_id"
    t.index ["tag_id"], name: "index_product_tags_on_tag_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "sku", null: false
    t.string "name"
    t.decimal "price", precision: 10, scale: 2
    t.decimal "compare_at_price", precision: 10, scale: 2
    t.string "color"
    t.string "size"
    t.string "material"
    t.string "style"
    t.decimal "weight", precision: 8, scale: 2
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
  end

  create_table "product_videos", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "video_url", null: false
    t.string "thumbnail_url"
    t.string "title"
    t.text "description"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_videos_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.text "short_description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "sku", null: false
    t.string "upc"
    t.string "manufacturer"
    t.integer "brand_id"
    t.integer "category_id"
    t.integer "seller_id"
    t.boolean "is_active", default: true
    t.boolean "is_featured", default: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["seller_id"], name: "index_products_on_seller_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "profiles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "birth_date"
    t.string "gender"
    t.text "bio"
    t.string "avatar"
    t.string "website"
    t.string "occupation"
    t.string "company"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "sub_categories", force: :cascade do |t|
    t.integer "category_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "position"
    t.string "slug", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_sub_categories_on_category_id"
    t.index ["name"], name: "index_sub_categories_on_name"
    t.index ["slug"], name: "index_sub_categories_on_slug", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "user_activities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "activity_type", null: false
    t.string "action"
    t.string "ip_address"
    t.string "user_agent"
    t.string "resource_type"
    t.integer "resource_id"
    t.text "details"
    t.datetime "activity_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_type", "resource_id"], name: "index_user_activities_on_resource_type_and_resource_id"
    t.index ["user_id", "activity_type"], name: "index_user_activities_on_user_id_and_activity_type"
    t.index ["user_id"], name: "index_user_activities_on_user_id"
  end

  create_table "user_devices", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "device_type"
    t.string "device_token"
    t.string "device_id", null: false
    t.string "os_type"
    t.string "os_version"
    t.string "app_version"
    t.datetime "last_used_at"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_user_devices_on_device_id", unique: true
    t.index ["user_id"], name: "index_user_devices_on_user_id"
  end

  create_table "user_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action"
    t.string "ip_address"
    t.string "user_agent"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_logs_on_user_id"
  end

  create_table "user_permissions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "permission_name", null: false
    t.string "resource_type"
    t.integer "resource_id"
    t.string "action", null: false
    t.boolean "is_allowed", default: true
    t.datetime "granted_at"
    t.datetime "expires_at"
    t.string "granted_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "permission_name", "resource_type", "resource_id", "action"], name: "index_user_permissions_on_user_and_permission", unique: true
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "email_notifications", default: true
    t.boolean "sms_notifications", default: false
    t.boolean "push_notifications", default: true
    t.string "language", default: "en"
    t.string "currency", default: "USD"
    t.string "timezone", default: "UTC"
    t.boolean "two_factor_auth", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_preferences_on_user_id"
  end

  create_table "user_rewards", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "reward_type"
    t.string "status", default: "active"
    t.integer "points"
    t.decimal "amount", precision: 10, scale: 2
    t.string "code"
    t.text "description"
    t.datetime "issued_at"
    t.datetime "expires_at"
    t.datetime "redeemed_at"
    t.text "redemption_details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_rewards_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "session_token", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_activity_at"
    t.datetime "expires_at"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_token"], name: "index_user_sessions_on_session_token", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "user_subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "subscription_type", null: false
    t.string "status", default: "active"
    t.datetime "start_date"
    t.datetime "end_date"
    t.decimal "amount", precision: 10, scale: 2
    t.string "billing_period"
    t.string "payment_method_id"
    t.datetime "last_payment_date"
    t.datetime "next_payment_date"
    t.boolean "auto_renew", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.boolean "active", default: true
    t.datetime "last_login_at"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer "failed_attempts", default: 0
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "addresses", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "payment_methods", "users"
  add_foreign_key "price_histories", "product_variants"
  add_foreign_key "price_histories", "products"
  add_foreign_key "product_accessories", "products"
  add_foreign_key "product_accessories", "products", column: "accessory_id"
  add_foreign_key "product_attributes", "products"
  add_foreign_key "product_bundle_items", "product_bundles"
  add_foreign_key "product_bundle_items", "products"
  add_foreign_key "product_descriptions", "products"
  add_foreign_key "product_documents", "products"
  add_foreign_key "product_images", "product_variants"
  add_foreign_key "product_images", "products"
  add_foreign_key "product_specifications", "products"
  add_foreign_key "product_tags", "products"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_videos", "products"
  add_foreign_key "profiles", "users"
  add_foreign_key "sub_categories", "categories"
  add_foreign_key "user_activities", "users"
  add_foreign_key "user_devices", "users"
  add_foreign_key "user_logs", "users"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "user_preferences", "users"
  add_foreign_key "user_rewards", "users"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_subscriptions", "users"
end
