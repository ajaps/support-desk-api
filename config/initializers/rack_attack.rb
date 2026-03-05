class Rack::Attack
  throttle("graphql/ip", limit: 60, period: 60, &:ip)

  # Tighter limit specifically on signIn / signUp mutations.
  # Inspects the request body so only auth operations are throttled.
  throttle("graphql/auth/ip", limit: 10, period: 60) do |req|
    next unless req.path == "/graphql" && req.post?

    begin
      body = req.body.read
      req.body.rewind
      query = JSON.parse(body)["query"].to_s
      req.ip if query.match?(/\b(signIn|signUp)\b/i)
    rescue
      nil
    end
  end

  # Per-user limit for authenticated GraphQL requests.
  # Extracts the user ID from the Bearer token without a full DB lookup.
  throttle("graphql/user", limit: 200, period: 60) do |req|
    next unless req.path == "/graphql" && req.post?

    token = req.get_header("HTTP_AUTHORIZATION").to_s[/Bearer (.+)/, 1]
    next unless token

    begin
      payload = JWT.decode(token, TokenService::SECRET, true, { algorithm: TokenService::ALG }).first
      "user:#{payload['sub']}"
    rescue JWT::DecodeError
      nil
    end
  end

  self.throttled_responder = lambda do |_env|
    [ 429, { "Content-Type" => "application/json" },
     [ '{"errors":[{"message":"Too many requests. Please slow down."}]}' ] ]
  end
end
