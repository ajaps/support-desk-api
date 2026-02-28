# frozen_string_literal: true

module Types
  class BaseConnection < Types::BaseObject
    field :total_count, Integer, null: false

    # add `nodes` and `pageInfo` fields, as well as `edge_type(...)` and `node_nullable(...)` overrides
    include GraphQL::Types::Relay::ConnectionBehaviors

    def total_count  
      object.items.size
    end
  end
end
