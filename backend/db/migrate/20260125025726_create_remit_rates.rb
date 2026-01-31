class CreateRemitRates < ActiveRecord::Migration[8.0]
  def change
    create_table :remit_rates do |t|
      t.string :provider, null: false
      t.decimal :rate, null: false
      t.string :currency, null: false, default: 'USD'

      t.timestamps
    end

    add_index :remit_rates, :provider
    add_index :remit_rates, :currency
    add_index :remit_rates, [ :provider, :currency ], unique: true
  end
end
