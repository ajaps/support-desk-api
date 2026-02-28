RSpec.shared_examples "requires authentication" do |query, variables: {}|
  it "returns an error when unauthenticated" do
    result = gql(query, variables: variables, current_user: nil)
    expect(result["errors"]).to be_present
    expect(result.dig("errors", 0, "message")).to match(/not authenticated/i)
  end
end

RSpec.shared_examples "agent only" do |query, variables: {}|
  it "returns an error for customers" do
    result = gql(query, variables: variables, current_user: create(:user))
    expect(result["errors"].first["message"]).to match(/not authorized/i)
  end
end