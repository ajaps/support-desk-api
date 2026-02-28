class AuthenticationError < StandardError; end

module Authenticatable
  extend ActiveSupport::Concern

  private

  # Call in before_action to require a valid JWT
  def authenticate!
    @current_user = decode_user_from_token!
  end

  # Like authenticate! but returns nil instead of raising (optional auth)
  def current_user
    @current_user ||= decode_user_from_token!
  rescue AuthenticationError
    nil
  end

  def decode_user_from_token!
    raw = request.headers["Authorization"]&.split(" ")&.last
    raise AuthenticationError, "Missing token" unless raw

    payload = TokenService.decode(raw)
    User.find(payload["sub"])
  rescue ActiveRecord::RecordNotFound
    raise AuthenticationError, "User not found"
  end
end