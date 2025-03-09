class CreateProductDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :product_documents do |t|
      t.references :product, null: false, foreign_key: true
      t.string :document_url, null: false
      t.string :title
      t.string :document_type
      t.integer :position, default: 0

      t.timestamps
    end
  end
end
