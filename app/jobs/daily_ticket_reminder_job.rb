require "csv"

class DailyTicketReminderJob < ApplicationJob
  queue_as :mailers

  def perform
    tickets = Ticket.where(closed_at: nil).includes(:customer, :agent)
    data = generate_csv(tickets)

    export = Export.create!(status: :completed, export_type: "daily_reminder")
    export.file.attach(
      io: StringIO.new(data),
      filename: "daily_ticket_reminder_#{Time.current.strftime('%Y_%m_%d')}.csv",
      content_type: "text/csv"
    )

    User.agent.find_each do |agent|
      OpenTicketsMailer.ready(agent, export).deliver_later
    end
  end

  private

  def generate_csv(tickets)
    CSV.generate(headers: true) do |csv|
      csv << %w[ID Title Customer Agent Status CreatedAt]
      tickets.each do |t|
        csv << [ t.id, t.title, t.customer&.name, t.agent&.name, (t.closed? ? "closed" : "open"), t.created_at ]
      end
    end
  end
end
