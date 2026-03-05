require "rails_helper"

RSpec.describe "GraphQL API", type: :request do
  let(:customer) { create(:user) }
  let(:agent)    { create(:user, :agent) }

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
                             current_user: customer)
      expect(result.dig("data", "createTicket", "ticket", "closedAt")).to be_nil
      expect(result.dig("data", "createTicket", "ticket", "status")).to eq("open")
    end

    it "prevents an agent from creating a ticket" do
      result = gql(mutation, variables: { title: "Help!", description: "Details" },
                             current_user: agent)
      expect(result.dig("errors")[0]["message"]).to match(/not authorized/i)
    end

    it "returns an error when unauthenticated" do
      result = gql(mutation, variables: { title: "Help!", description: "Details" })
      expect(result["errors"]).to be_present
    end
  end

  describe "tickets query" do
    let(:query) { "{ tickets { totalCount nodes { id createdAt } } }" }

    it "returns only the customer's own tickets" do
      create(:ticket, customer: customer)
      create(:ticket)   # belongs to another customer

      result = gql(query, current_user: customer)
      expect(result.dig("data", "tickets", "totalCount")).to eq(1)
    end

    it "returns all tickets for an agent" do
      create_list(:ticket, 3)
      result = gql(query, current_user: agent)
      expect(result.dig("data", "tickets", "totalCount")).to eq(3)
    end
  end

  describe "node query" do
    let(:ticket) { create(:ticket, customer: customer) }

    let(:node_query) do
      <<~GQL
        query($id: ID!) { node(id: $id) { id } }
      GQL
    end

    it "returns the object when the user is authorized" do
      result = gql(node_query, variables: { id: ticket.to_gid_param }, current_user: customer)
      expect(result.dig("data", "node", "id")).to be_present
    end

    it "returns a not-authorized error when the user cannot see the object" do
      other_ticket = create(:ticket)
      result = gql(node_query, variables: { id: other_ticket.to_gid_param }, current_user: customer)
      expect(result.dig("errors", 0, "message")).to match(/not authorized/i)
    end

    it "returns a not-authenticated error when unauthenticated" do
      result = gql(node_query, variables: { id: ticket.to_gid_param })
      expect(result.dig("errors", 0, "message")).to match(/not authenticated/i)
    end

    it "returns null when the record no longer exists" do
      gid = ticket.to_gid_param
      ticket.destroy
      result = gql(node_query, variables: { id: gid }, current_user: customer)
      expect(result.dig("data", "node")).to be_nil
    end

    it "allows an agent to fetch their own export" do
      export = create(:export, agent: agent)
      export_query = <<~GQL
        query($id: ID!) { node(id: $id) { id } }
      GQL
      result = gql(export_query, variables: { id: export.to_gid_param }, current_user: agent)
      expect(result.dig("data", "node", "id")).to be_present
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
      result = gql(mutation, variables: { id: ticket.id }, current_user: agent)
      expect(result.dig("data", "closeTicket", "ticket", "status")).to eq("closed")
    end

    # it "allows a customer to also close ticket" do
    #   result = gql(mutation, variables: { id: ticket.id },
    #                          current_user: customer)
    #   expect(result.dig("data", "closeTicket", "ticket", "status")).to eq("closed")
    # end
  end
end
