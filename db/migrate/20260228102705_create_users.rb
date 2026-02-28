class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email,           null: false
      t.string :password_digest, null: false
      t.string :name,            null: false
      t.integer :role,           null: false, default: 0  # enum: { customer: 0, agent: 1 }

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
  end
end
