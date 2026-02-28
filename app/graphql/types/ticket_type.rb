module Types
  class TicketType < BaseObject
    # Tell graphql-ruby to use our custom connection & edge types
    connection_type_class Types::BaseConnection
    edge_type_class       Types::BaseEdge

    field :id,          ID,          null: false
    field :title,       String,      null: false
    field :description, String,      null: false
    field :customer,    UserType,    null: false
    field :agent,       UserType,    null: true
    field :comments,    [ CommentType ], null: false
    field :attachment_urls, [ String ], null: false
    field :created_at,  GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at,  GraphQL::Types::ISO8601DateTime, null: false
    field :closed_at,  GraphQL::Types::ISO8601DateTime, null: true
    field :status,      String,      null: false

    def comments
      object.comments.order(created_at: :asc)
    end

    def status
      object.status
    end

    def attachment_urls
      object.attachments.map { |a| Rails.application.routes.url_helpers.rails_blob_url(a) }
    end
  end
end
