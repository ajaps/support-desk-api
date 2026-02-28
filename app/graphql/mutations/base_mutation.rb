# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    private

    def current_user
      context[:current_user] || raise(GraphQL::ExecutionError, "Not authenticated")
    end

    def require_agent!
      raise GraphQL::ExecutionError, "Agents only" unless current_user.agent?
    end
  end
end
