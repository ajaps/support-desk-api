module Mutations
  module Tickets
    class AssignTicket < BaseMutation
      argument :ticket_id, ID, required: true

      field :ticket, Types::TicketType, null: true
      field :errors, [ String ], null: false

      def resolve(ticket_id:)
        # Authorize role before record lookup so non-agents get a clear auth error
        # even when the ticket ID is invalid or doesn't exist.
        ticket = Ticket.find_by(id: ticket_id)
        authorize! ticket || Ticket.new, :update?

        return { ticket: nil, errors: [ "Ticket not found" ] } unless ticket

        if ticket.update(agent: current_user)
          { ticket: ticket, errors: [] }
        else
          { ticket: nil, errors: ticket.errors.full_messages }
        end
      end
    end
  end
end
