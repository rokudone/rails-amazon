class CreateProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.date :birth_date
      t.string :gender
      t.text :bio
      t.string :avatar
      t.string :website
      t.string :occupation
      t.string :company

      t.timestamps
    end
  end
end
