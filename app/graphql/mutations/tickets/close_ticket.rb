module Mutations
  module Tickets
    class CloseTicket < BaseMutation
      argument :ticket_id, ID,     required: true

      field :ticket, Types::TicketType, null: true
      field :errors, [String], null: false

      def resolve(ticket_id:)
        # require_agent!
        ticket = Ticket.find(ticket_id)
        
        if ticket.close!
          { ticket: ticket, errors: [] }
        else
          { ticket: nil, errors: ticket.errors.full_messages }
        end
      end
    end
  end
end