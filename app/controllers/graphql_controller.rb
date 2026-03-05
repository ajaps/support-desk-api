# frozen_string_literal: true

class GraphqlController < ApplicationController
  include Authenticatable

  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: current_user,
      request: request
    }
    result = SupportDeskApiSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result

  rescue AuthenticationError => e
    render json: { errors: [ { message: e.message } ] }, status: :unauthorized
  rescue ArgumentError => e
    render json: { errors: [ { message: e.message } ] }, status: :bad_request
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # Accept only Hash, JSON string, or nil — reject anything else with a 400.
  def prepare_variables(variables_param)
    case variables_param
    when String
      variables_param.present? ? JSON.parse(variables_param) : {}
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash
    when nil
      {}
    else
      raise ArgumentError, "Invalid variables format"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end
end
