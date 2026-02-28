class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.references :agent, foreign_key: { to_table: :users }
      t.datetime :closed_at
      t.timestamps
    end

    add_index :tickets, :created_at
  end
end
