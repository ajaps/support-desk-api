# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :tickets, [TicketType], null: false do
      argument :status, String, required: false
    end

    def tickets(status: nil)
      raise GraphQL::ExecutionError, "Not authenticated" unless context[:current_user]

      scope = if context[:current_user].agent?
                Ticket.all
              else
                context[:current_user].tickets_as_customer
              end
      if status&.include?("open")
        scope = scope.where(closed_at: nil)
      elsif status&.include?("closed")
        scope = scope.where.not(closed_at: nil)
      end
      
      scope.order(created_at: :desc)
    end

    # Single ticket
    field :ticket, TicketType, null: true do
      argument :id, ID, required: true
    end

    def ticket(id:)
      raise GraphQL::ExecutionError, "Not authenticated" unless context[:current_user]

      ticket = Ticket.find_by(id: id)
      return nil unless ticket

      user = context[:current_user]
      return ticket if user.agent?
      return ticket if ticket.customer_id == user.id

      raise GraphQL::ExecutionError, "Not authorized"
    end

    # Current user
    field :me, UserType, null: true

    def me
      context[:current_user]
    end
  end
end
