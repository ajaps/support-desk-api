module Mutations
  module Tickets
    class CreateTicket < BaseMutation
      argument :title,       String, required: true
      argument :description, String, required: true

      field :ticket, Types::TicketType, null: true
      field :errors, [ String ], null: false

      def resolve(title:, description:)
        raise GraphQL::ExecutionError, "Customers only" unless current_user.customer?

        ticket = current_user.tickets_as_customer.build(title: title, description: description)
        authorize! ticket, :create?

        if ticket.save
          { ticket: ticket, errors: [] }
        else
          { ticket: nil, errors: ticket.errors.full_messages }
        end
      end
    end
  end
end
