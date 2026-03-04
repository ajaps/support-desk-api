module Types
  class TicketType < BaseObject
    connection_type_class Types::BaseConnection
    edge_type_class       Types::BaseEdge

    field :id,          ID,          null: false
    field :title,       String,      null: false
    field :description, String,      null: false
    field :customer,    UserType,    null: false
    field :agent,       UserType,    null: true
    field :comments,    [ CommentType ], null: false
    field :created_at,  GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at,  GraphQL::Types::ISO8601DateTime, null: false
    field :closed_at,        GraphQL::Types::ISO8601DateTime, null: true
    field :agent_replied_at, GraphQL::Types::ISO8601DateTime, null: true
    field :status,           String,      null: false
    field :file_url,    String,      null: true

    def comments
      object.comments.order(created_at: :asc)
    end

    def status
      object.status
    end

    def file_url
      return unless object.file.attached?

      Rails.application.routes.url_helpers.rails_blob_url(
        object.file,
        expires_in: 10.minutes
      )
    end
  end
end
