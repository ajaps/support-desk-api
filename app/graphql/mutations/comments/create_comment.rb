module Mutations
  module Comments
    class CreateComment < BaseMutation
      argument :ticket_id, ID,     required: true
      argument :body,      String, required: true

      field :comment, Types::CommentType, null: true
      field :errors,  [ String ], null: false

      def resolve(ticket_id:, body:)
        ticket = Ticket.find(ticket_id)
        authorize! ticket, :add_comment?

        comment = ticket.comments.build(user: current_user, body: body)

        ActiveRecord::Base.transaction do
          comment.save!

          # Automatically assign the ticket to the commenting agent if it's unassigned
          if current_user.agent? && ticket.agent_id.nil?
            ticket.update!(agent: current_user)
          end
        end

        { comment: comment, errors: [] }
      rescue ActiveRecord::RecordInvalid => e
        { comment: nil, errors: e.record.errors.full_messages }
      end
    end
  end
end
