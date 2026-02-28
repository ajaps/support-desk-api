class Rack::Attack
  throttle("graphql/ip", limit: 60, period: 60, &:ip)

  # Tighter limit specifically on auth mutations
  throttle("graphql/auth/ip", limit: 10, period: 60) do |req|
    req.ip if req.path == "/graphql" && req.post?
  end

  self.throttled_responder = lambda do |_env|
    [ 429, { "Content-Type" => "application/json" },
     [ '{"errors":[{"message":"Too many requests. Please slow down."}]}' ] ]
  end
end
