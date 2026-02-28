require "rails_helper"

RSpec.describe "GraphQL API", type: :request do
  let(:customer) { create(:user) }
  let(:agent)    { create(:user, :agent) }

  def gql(query, variables: {}, user: nil)
    headers = {}
    headers["Authorization"] = "Bearer #{TokenService.encode(user)}" if user
    post "/graphql",
         params: { query: query, variables: variables.to_json }.to_json,
         headers: headers.merge("Content-Type" => "application/json")
    JSON.parse(response.body)
  end

  # ── Auth ──────────────────────────────────────────────────────────────────
  describe "signUp mutation" do
    let(:mutation) do
      <<~GQL
        mutation SignUp($name: String!, $email: String!, $password: String!) {
          signUp(input: { name: $name, email: $email, password: $password }) {
            token
            errors
          }
        }
      GQL
    end

    it "creates a customer and returns a token" do
      result = gql(mutation, variables: {
        name: "Alice", email: "alice@test.com", password: "Password1!"
      })
      expect(result.dig("data", "signUp", "token")).to be_present
      expect(result.dig("data", "signUp", "errors")).to be_empty
    end
  end

  # ── Tickets ───────────────────────────────────────────────────────────────
  describe "createTicket mutation" do
    let(:mutation) do
      <<~GQL
        mutation CreateTicket($title: String!, $description: String!) {
          createTicket(input: { title: $title, description: $description }) {
            ticket { id closedAt status }
            errors
          }
        }
      GQL
    end

    it "allows a customer to create a ticket" do
      result = gql(mutation, variables: { title: "Help!", description: "Details" },
                             user: customer)
      expect(result.dig("data", "createTicket", "ticket", "closedAt")).to be_nil
      expect(result.dig("data", "createTicket", "ticket", "status")).to eq("open")
    end

    it "prevents an agent from creating a ticket" do
      result = gql(mutation, variables: { title: "Help!", description: "Details" },
                             user: agent)
      expect(result.dig("errors")[0]["message"]).to eq("Customers only")
    end

    it "returns an error when unauthenticated" do
      result = gql(mutation, variables: { title: "Help!", description: "Details" })
      expect(result["errors"]).to be_present
    end
  end

  describe "tickets query" do
    let(:query) { "{ tickets { id createdAt } }" }

    it "returns only the customer's own tickets" do
      create(:ticket, customer: customer)
      create(:ticket)   # belongs to another customer

      result = gql(query, user: customer)
      expect(result.dig("data", "tickets").size).to eq(1)
    end

    it "returns all tickets for an agent" do
      create_list(:ticket, 3)
      result = gql(query, user: agent)
      expect(result.dig("data", "tickets").size).to eq(3)
    end
  end

  describe "closeTicket mutation" do
    let(:ticket) { create(:ticket) }
    let(:mutation) do
      <<~GQL
        mutation CloseTicket($id: ID!) {
          closeTicket(input: { ticketId: $id }) {
            ticket { status }
            errors
          }
        }
      GQL
    end

    it "allows an agent to close a ticket" do
      result = gql(mutation, variables: { id: ticket.id }, user: agent)
      expect(result.dig("data", "closeTicket", "ticket", "status")).to eq("closed")
    end

    it "allows a customer to also close ticket" do
      result = gql(mutation, variables: { id: ticket.id },
                             user: customer)
      expect(result.dig("data", "closeTicket", "ticket", "status")).to eq("closed")
    end
  end
end