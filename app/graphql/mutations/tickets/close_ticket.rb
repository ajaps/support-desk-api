module Mutations
  module Tickets
    class CloseTicket < BaseMutation
      argument :ticket_id, ID,     required: true

      field :ticket, Types::TicketType, null: true
      field :errors, [ String ], null: false

      def resolve(ticket_id:)
        ticket = Ticket.find(ticket_id)
        authorize! ticket, :update?

        # Automatically assign the ticket to the closing agent if it's unassigned
        ticket.update!(agent: current_user) if ticket.agent_id.nil?

        if ticket.may_close?
          ticket.close!
          { ticket: ticket, errors: [] }
        else
          { ticket: nil, errors: [ "Ticket is already closed" ] }
        end
      end
    end
  end
end
