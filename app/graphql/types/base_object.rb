# frozen_string_literal: true

module Types
  class BaseObject < GraphQL::Schema::Object
    edge_type_class(GraphQL::Types::Relay::BaseEdge)
    connection_type_class(GraphQL::Types::Relay::BaseConnection)
    field_class Types::BaseField
  end
end
