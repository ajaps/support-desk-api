class ExportTicketsJob < ApplicationJob
  queue_as :exports

  retry_on StandardError, attempts: 3, wait: :polynomially_longer

  def perform(export_id, user_id)
    begin
      export = Export.find(export_id)
      ticket_ids = export.ticket_array.split(",").map(&:to_i)
      tickets = Ticket.where(id: ticket_ids).includes(:customer, :agent)
      user    = User.find(user_id)

      file_content = generate_csv(tickets)

      filename = "closed_tickets_#{Time.current.strftime('%Y_%m_%d_%H_%M')}.csv"

      export = user.exports.create!(status: :pending, export_type: "recently_closed_tickets")
      export.file.attach(
        io: StringIO.new(file_content),
        filename: filename,
        content_type: "text/csv"
      )

      ExportMailer.ready(user, export).deliver_later
    rescue => e
      export&.update(status: "failed", error_message: e.message)
      raise
    end
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
