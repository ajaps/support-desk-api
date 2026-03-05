class AddStatusToTickets < ActiveRecord::Migration[8.1]
  def up
    add_column :tickets, :status, :integer, default: 0, null: false

    execute "UPDATE tickets SET status = 2 WHERE closed_at IS NOT NULL"
    execute "UPDATE tickets SET status = 1 WHERE closed_at IS NULL AND agent_replied_at IS NOT NULL"
  end

  def down
    remove_column :tickets, :status
  end
end
