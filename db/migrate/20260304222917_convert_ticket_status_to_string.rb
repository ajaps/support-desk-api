class ConvertTicketStatusToString < ActiveRecord::Migration[8.1]
  # The previous migration stored status as an integer enum (0=open, 1=awaiting_customer, 2=closed).
  # AASM stores state as a string. This migration converts the column and maps existing values.
  # It also introduces the new 'awaiting_agent' state (no existing rows map to it yet).

  def up
    add_column :tickets, :status_new, :string, default: "open", null: false

    execute <<~SQL
      UPDATE tickets
      SET status_new = CASE status
        WHEN 0 THEN 'open'
        WHEN 1 THEN 'awaiting_customer'
        WHEN 2 THEN 'closed'
        ELSE 'open'
      END
    SQL

    remove_column :tickets, :status
    rename_column :tickets, :status_new, :status
  end

  def down
    add_column :tickets, :status_int, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE tickets
      SET status_int = CASE status
        WHEN 'open'              THEN 0
        WHEN 'awaiting_agent'    THEN 0
        WHEN 'awaiting_customer' THEN 1
        WHEN 'closed'            THEN 2
        ELSE 0
      END
    SQL

    remove_column :tickets, :status
    rename_column :tickets, :status_int, :status
  end
end
