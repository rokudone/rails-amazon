class CreateUserPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :email_notifications, default: true
      t.boolean :sms_notifications, default: false
      t.boolean :push_notifications, default: true
      t.string :language, default: "en"
      t.string :currency, default: "USD"
      t.string :timezone, default: "UTC"
      t.boolean :two_factor_auth, default: false

      t.timestamps
    end
  end
end
