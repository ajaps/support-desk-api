class AddAgentRepliedAtToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :agent_replied_at, :datetime
  end
end
