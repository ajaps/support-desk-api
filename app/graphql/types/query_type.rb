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

    field :me, UserType, null: true

    def me
      context[:current_user]
    end

    field :average_agent_response_time, String, null: true,
          description: "Human-readable average time between ticket creation and first agent reply for the current month. Agents only."

    def average_agent_response_time
      raise GraphQL::ExecutionError, "Not authenticated" unless context[:current_user]
      raise GraphQL::ExecutionError, "Not authorized" unless context[:current_user].agent?

      period_start = Date.current.beginning_of_month.beginning_of_day
      period_end   = Date.current.end_of_month.end_of_day

      sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL, period_start, period_end ])
        SELECT AVG(
          EXTRACT(EPOCH FROM (first_reply.replied_at - tickets.created_at))
        )
        FROM tickets
        INNER JOIN (
          SELECT comments.ticket_id, MIN(comments.created_at) AS replied_at
          FROM comments
          INNER JOIN users ON users.id = comments.user_id
          WHERE users.role = 1
          GROUP BY comments.ticket_id
        ) first_reply ON first_reply.ticket_id = tickets.id
        WHERE tickets.created_at >= ?
          AND tickets.created_at <= ?
      SQL
      result = ActiveRecord::Base.connection.select_value(sql)

      return nil unless result

      humanize_duration(result.to_f)
    end

    private

    def humanize_duration(seconds)
      total_minutes = (seconds / 60).round
      days    = total_minutes / (60 * 24)
      remaining = total_minutes % (60 * 24)
      hours   = remaining / 60
      minutes = remaining % 60

      parts = []
      parts << "#{days} #{days == 1 ? 'day' : 'days'}"       if days > 0
      parts << "#{hours} #{hours == 1 ? 'hour' : 'hours'}"   if hours > 0
      parts << "#{minutes} #{minutes == 1 ? 'minute' : 'minutes'}" if minutes > 0
      parts << "less than a minute" if parts.empty?

      parts.join(" ")
    end
  end
end
