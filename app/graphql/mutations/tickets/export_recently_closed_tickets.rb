module Mutations
  module Tickets
    class ExportRecentlyClosedTickets < BaseMutation
      field :id, ID, null: true
      field :message, String, null: false
      field :success, Boolean, null: false

      def resolve
        authorize! Ticket.new, :export?

        ticket_ids = Ticket.recently_closed.pluck(:id)
        filename   = "closed_tickets_#{Time.current.strftime('%Y_%m_%d_%H_%M')}.csv"

        export = current_user.exports.create!(
          status:       :pending,
          export_type:  "recently_closed_tickets",
          filename:     filename,
          ticket_array: ticket_ids.to_json
        )

        ExportTicketsJob.perform_later(export.id, current_user.id)

        { id: export.id, message: "Export started. You'll receive an email when it is ready.", success: true }
      rescue ActiveRecord::RecordInvalid => e
        { id: nil, message: e.record.errors.full_messages.first, success: false }
      end
    end
  end
end
