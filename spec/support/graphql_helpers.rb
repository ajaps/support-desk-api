module GraphqlHelpers
  def gql(query, variables: {}, current_user: nil)
    SupportDeskApiSchema.execute(
      query,
      variables: variables,
      context:   { current_user: current_user },
    ).to_h
  end

  def http_gql(query, variables: {}, current_user: nil)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{TokenService.encode(current_user)}" if current_user
    post "/graphql",
         params:  { query: query, variables: variables.to_json }.to_json,
         headers: headers
    JSON.parse(response.body)
  end
end