class CreateInvoices < ActiveRecord::Migration[7.0]
  def change
    create_table :invoices do |t|
      t.string :invoice_number, null: false
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :invoice_date, null: false
      t.datetime :due_date
      t.string :status, default: 'pending' # 'pending', 'paid', 'partially_paid', 'overdue', 'cancelled', 'refunded'
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :tax_total, precision: 10, scale: 2, default: 0
      t.decimal :shipping_total, precision: 10, scale: 2, default: 0
      t.decimal :discount_total, precision: 10, scale: 2, default: 0
      t.decimal :grand_total, precision: 12, scale: 2, null: false
      t.decimal :amount_paid, precision: 12, scale: 2, default: 0
      t.decimal :amount_due, precision: 12, scale: 2
      t.string :currency, default: 'USD'
      t.string :payment_terms # 'due_on_receipt', 'net_15', 'net_30', 'net_60'
      t.text :notes
      t.string :billing_name
      t.string :billing_company
      t.text :billing_address_line1
      t.text :billing_address_line2
      t.string :billing_city
      t.string :billing_state
      t.string :billing_postal_code
      t.string :billing_country
      t.string :billing_phone
      t.string :billing_email
      t.string :shipping_name
      t.string :shipping_company
      t.text :shipping_address_line1
      t.text :shipping_address_line2
      t.string :shipping_city
      t.string :shipping_state
      t.string :shipping_postal_code
      t.string :shipping_country
      t.string :tax_id
      t.string :tax_exemption_number
      t.string :invoice_pdf_url
      t.datetime :sent_at
      t.datetime :viewed_at
      t.integer :view_count, default: 0
      t.string :created_by
      t.jsonb :metadata

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :status
    add_index :invoices, :invoice_date
    add_index :invoices, :due_date
  end
end
