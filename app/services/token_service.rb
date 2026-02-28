class TokenService
  SECRET = Rails.application.credentials.jwt_secret!
  TTL    = 24.hours.to_i
  ALG    = "HS256"

  # Encode a JWT for the given user
  def self.encode(user)
    payload = {
      sub:  user.id,
      role: user.role,
      jti:  SecureRandom.uuid,   # unique token ID — store in a denylist to support logout
      exp:  Time.now.to_i + TTL,
      iat:  Time.now.to_i
    }
    JWT.encode(payload, SECRET, ALG)
  end

  # Decode and verify; raises AuthenticationError on any failure
  def self.decode(token)
    JWT.decode(token, SECRET, true, { algorithm: ALG }).first
  rescue JWT::ExpiredSignature
    raise AuthenticationError, "Token has expired"
  rescue JWT::DecodeError => e
    raise AuthenticationError, "Invalid token: #{e.message}"
  end
end
