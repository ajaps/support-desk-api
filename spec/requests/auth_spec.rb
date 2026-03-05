require "rails_helper"

RSpec.describe "Auth mutations", type: :request do
  SIGN_UP = <<~GQL
    mutation SignUp($name: String!, $email: String!, $password: String!) {
      signUp(input: { name: $name, email: $email, password: $password }) {
        token user { id email role } errors
      }
    }
  GQL

  SIGN_IN = <<~GQL
    mutation SignIn($email: String!, $password: String!) {
      signIn(input: { email: $email, password: $password }) {
        token user { id email role } errors
      }
    }
  GQL

  describe "signUp" do
    it "creates a customer and returns a token" do
      result = gql(SIGN_UP, variables: { name: "Alice", email: "alice@test.com",
                                         password: "Password1!" })
      expect(result.dig("data", "signUp", "token")).to be_present
      expect(result.dig("data", "signUp", "user", "role")).to eq("customer")
      expect(result.dig("data", "signUp", "errors")).to be_empty
    end

    it "always creates a customer regardless of any attempted role injection" do
      result = gql(SIGN_UP, variables: { name: "Bob", email: "bob@test.com",
                                         password: "Password1!" })
      expect(result.dig("data", "signUp", "user", "role")).to eq("customer")
    end

    it "returns errors for a duplicate email" do
      create(:user, email: "dup@test.com")
      result = gql(SIGN_UP, variables: { name: "X", email: "dup@test.com",
                                         password: "Password1!" })
      expect(result.dig("data", "signUp", "errors")).to be_present
      expect(result.dig("data", "signUp", "token")).to be_nil
    end

    it "returns errors for a weak password" do
      result = gql(SIGN_UP, variables: { name: "X", email: "x@test.com",
                                         password: "short" })
      expect(result.dig("data", "signUp", "errors")).to be_present
    end

    it "returns errors for an invalid email" do
      result = gql(SIGN_UP, variables: { name: "X", email: "not-an-email",
                                         password: "Password1!" })
      expect(result.dig("data", "signUp", "errors")).to be_present
    end
  end

  describe "authentication middleware" do
    it "returns an error when the token's user no longer exists" do
      user  = create(:user, email: "gone@test.com", password: "Password1!")
      token = TokenService.encode(user)
      user.destroy!

      post "/graphql",
           params:  { query: "{ tickets { totalCount } }", variables: "{}" }.to_json,
           headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }

      data = JSON.parse(response.body)
      expect(data.dig("errors", 0, "message")).to match(/not authenticated/i)
    end
  end

  describe "me query" do
    let!(:user) { create(:user, email: "me@test.com", password: "Password1!") }

    it "returns the current user" do
      result = gql("{ me { id email } }", current_user: user)
      expect(result.dig("data", "me", "email")).to eq("me@test.com")
    end
  end

  describe "signIn" do
    let!(:user) { create(:user, email: "login@test.com", password: "Password1!") }

    it "returns a token for valid credentials" do
      result = gql(SIGN_IN, variables: { email: "login@test.com", password: "Password1!" })
      expect(result.dig("data", "signIn", "token")).to be_present
      expect(result.dig("data", "signIn", "errors")).to be_empty
    end

    it "is case-insensitive on email" do
      result = gql(SIGN_IN, variables: { email: "LOGIN@TEST.COM", password: "Password1!" })
      expect(result.dig("data", "signIn", "token")).to be_present
    end

    it "returns an error for a wrong password" do
      result = gql(SIGN_IN, variables: { email: "login@test.com", password: "wrong" })
      expect(result.dig("data", "signIn", "token")).to be_nil
      expect(result.dig("data", "signIn", "errors")).to include(match(/invalid/i))
    end

    it "returns an error for an unknown email" do
      result = gql(SIGN_IN, variables: { email: "ghost@test.com", password: "Password1!" })
      expect(result.dig("data", "signIn", "errors")).to be_present
    end
  end
end
