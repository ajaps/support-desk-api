module Mutations
  module Tickets
    class CreateTicket < BaseMutation
      argument :title,       String, required: true
      argument :description, String, required: true
      argument :file_signed_id, String, required: false

      field :ticket, Types::TicketType, null: true
      field :errors, [ String ], null: false

      def resolve(title:, description:, file_signed_id: nil)
        ticket = current_user.tickets_as_customer.build(title: title, description: description)
        ticket.file.attach(file_signed_id) if file_signed_id.present?

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
