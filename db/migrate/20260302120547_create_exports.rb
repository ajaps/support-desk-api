class CreateExports < ActiveRecord::Migration[8.1]
  def change
    create_table :exports do |t|
      t.references :agent, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.string :export_type, null: false
      t.text :error_message
      t.string :filename
      t.text :ticket_array

      t.timestamps
    end

    add_index :exports, [ :agent_id, :filename ], unique: true, name: "index_exports_on_agent_id_and_filename_pending_only"
  end
end
