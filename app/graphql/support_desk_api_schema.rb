# frozen_string_literal: true

class SupportDeskApiSchema < GraphQL::Schema
  mutation(Types::MutationType)
  query(Types::QueryType)

  orphan_types Types::ExportType

  # For batch-loading (see https://graphql-ruby.org/dataloader/overview.html)
  use GraphQL::Dataloader

  def self.unauthorized_object(error)
    raise GraphQL::ExecutionError, "Unauthorized: #{error.message}"
  end

  # GraphQL-Ruby calls this when something goes wrong while running a query:
  def self.type_error(err, context)
    super
  end

  # Union and Interface Resolution
  def self.resolve_type(abstract_type, obj, ctx)
    case obj
    when Ticket  then Types::TicketType
    when Comment then Types::CommentType
    when User    then Types::UserType
    when Export  then Types::ExportType
    else raise "resolve_type: unhandled type #{obj.class}"
    end
  end

  # Limit the size of incoming queries:
  max_query_string_tokens(5000)

  # Prevent deeply nested queries that could cause exponential resolver calls.
  max_depth(10)

  # Cap pages to 100 nodes so agents cannot load the entire dataset in one request.
  default_max_page_size(100)

  # Stop validating when it encounters this many errors:
  validate_max_errors(100)

  # Relay-style Object Identification:

  # Return a string UUID for `object`
  def self.id_from_object(object, type_definition, query_ctx)
    object.to_gid_param
  end

  # Given a string UUID, find the object — enforces Pundit show? on every lookup.
  def self.object_from_id(global_id, query_ctx)
    current_user = query_ctx[:current_user]
    raise GraphQL::ExecutionError, "Not authenticated" unless current_user

    object = GlobalID.find(global_id)
    return nil unless object

    policy = Pundit.policy!(current_user, object)
    raise GraphQL::ExecutionError, "Not authorized" unless policy.show?

    object
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
