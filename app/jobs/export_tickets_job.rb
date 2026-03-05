require "csv"

class ExportTicketsJob < ApplicationJob
  queue_as :exports

  retry_on StandardError, attempts: 3, wait: :polynomially_longer

  def perform(export_id, user_id)
    export = Export.find(export_id)
    ticket_ids = export.ticket_array.present? ? JSON.parse(export.ticket_array) : []
    tickets = Ticket.where(id: ticket_ids).includes(:customer, :agent)
    user    = User.find(user_id)

    file_content = generate_csv(tickets)

    export.file.attach(
      io: StringIO.new(file_content),
      filename: export.filename,
      content_type: "text/csv"
    )

    ExportMailer.ready(user, export).deliver_later
    export.update(status: :completed)
  rescue => e
    export&.update!(status: "failed", error_message: e.message)
    raise
  end

  private

  def generate_csv(tickets)
    CSV.generate(headers: true) do |csv|
      csv << %w[ID Title Customer Agent Status CreatedAt ClosedAt]
      tickets.each do |t|
        csv << [ t.id, t.title, t.customer&.name, t.agent&.name, (t.closed? ? "closed" : "open"), t.created_at, t.closed_at ]
      end
    end
  end
end
