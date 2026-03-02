class CreateExports < ActiveRecord::Migration[8.1]
  def change
    create_table :exports do |t|
      t.references :agent, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.datetime :exported_at, null: false
      t.string :export_type, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :exports, [ :agent_id, :created_at ]
  end
end
