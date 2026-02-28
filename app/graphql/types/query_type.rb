# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include Pundit::Authorization

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

    field :tickets, Types::TicketType.connection_type, null: false do
      argument :status, String, required: false
    end

    def tickets(status: nil)
      raise GraphQL::ExecutionError, "Not authenticated" unless context[:current_user]

      scope = Pundit.policy_scope!(context[:current_user], Ticket)
      if status&.downcase&.include?("open")
        scope = scope.where(closed_at: nil)
      elsif status&.downcase&.include?("close")
        scope = scope.where.not(closed_at: nil)
      end

      scope.order(created_at: :desc)
    end

    field :ticket, TicketType, null: true do
      argument :id, ID, required: true
    end

    def ticket(id:)
      raise GraphQL::ExecutionError, "Not authenticated" unless context[:current_user]

      ticket = Pundit.policy_scope!(context[:current_user], Ticket).find_by(id: id)

      raise GraphQL::ExecutionError, "Not found or not authorized" unless ticket

      ticket
    end

    # Current user
    field :me, UserType, null: true

    def me
      context[:current_user]
    end
  end
end
