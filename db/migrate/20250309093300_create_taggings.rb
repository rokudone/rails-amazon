class CreateTaggings < ActiveRecord::Migration[7.1]
  def change
    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: true
      t.references :taggable, polymorphic: true, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :context
      t.float :relevance, default: 1.0
      t.boolean :is_auto_generated, default: false
      t.boolean :is_approved, default: true
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :taggings, [:taggable_type, :taggable_id, :tag_id], unique: true, name: 'index_taggings_on_taggable_and_tag'
    add_index :taggings, [:taggable_type, :taggable_id, :context], name: 'index_taggings_on_taggable_and_context'
  end
end
