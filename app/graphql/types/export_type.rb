module Types
  class ExportType < BaseObject
    connection_type_class Types::BaseConnection
    edge_type_class       Types::BaseEdge

    field :id,          ID,          null: false
    field :status,       String,      null: false
    field :export_type, String,      null: false
    field :exported_at,    GraphQL::Types::ISO8601DateTime,    null: false
    field :agent,           UserType,    null: true
    field :download_url,    String,      null: true

    def download_url
      object.presigned_url
    end
  end
end
