module Mutations
  module Comments
    class CreateComment < BaseMutation
      argument :ticket_id, ID,     required: true
      argument :body,      String, required: true

      field :comment, Types::CommentType, null: true
      field :errors,  [ String ], null: false

      def resolve(ticket_id:, body:)
        ticket = Ticket.find(ticket_id)

        # Customers may only comment on their own tickets
        if current_user.customer? && ticket.customer_id != current_user.id
          raise GraphQL::ExecutionError, "Not authorized"
        end

        comment = ticket.comments.build(user: current_user, body: body)
        if comment.save
          { comment: comment, errors: [] }
        else
          { comment: nil, errors: comment.errors.full_messages }
        end
      end
    end
  end
end
