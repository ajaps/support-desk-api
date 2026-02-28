# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    def ready?(**args)
      return true if public_mutation?

      raise GraphQL::ExecutionError, "Not authenticated" unless context[:current_user]
      true
    end

    private

    def public_mutation?
      false
    end

    def current_user
      context[:current_user] || raise(GraphQL::ExecutionError, "Not authenticated")
    end

    def require_agent!
      raise GraphQL::ExecutionError, "not authorized" unless current_user.agent?
    end
  end
end
