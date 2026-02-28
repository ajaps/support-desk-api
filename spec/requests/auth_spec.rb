require "rails_helper"

RSpec.describe "Auth mutations", type: :request do
  SIGN_UP = <<~GQL
    mutation SignUp($name: String!, $email: String!, $password: String!, $role: String) {
      signUp(input: { name: $name, email: $email, password: $password, role: $role }) {
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

    it "creates an agent when role is specified" do
      result = gql(SIGN_UP, variables: { name: "Bob", email: "bob@test.com",
                                         password: "Password1!", role: "agent" })
      expect(result.dig("data", "signUp", "user", "role")).to eq("agent")
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