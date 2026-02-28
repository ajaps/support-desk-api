require "rails_helper"

RSpec.describe "Ticket mutations and queries", type: :request do
  let(:customer)       { create(:user) }
  let(:other_customer) { create(:user) }
  let(:agent)          { create(:user, :agent) }

  CREATE_TICKET = <<~GQL
    mutation CreateTicket($title: String!, $description: String!) {
      createTicket(input: { title: $title, description: $description }) {
        ticket { id title status } errors
      }
    }
  GQL

  GET_TICKETS = <<~GQL
    query GetTickets($status: String, $first: Int, $after: String) {
      tickets(status: $status, first: $first, after: $after) {
        totalCount
        pageInfo { hasNextPage endCursor }
        edges { node { id title status } }
      }
    }
  GQL

  GET_TICKET = <<~GQL
    query GetTicket($id: ID!) {
      ticket(id: $id) { id title description status }
    }
  GQL

  CLOSE_TICKET = <<~GQL
    mutation CloseTicket($ticketId: ID!) {
      closeTicket(input: { ticketId: $ticketId }) {
        ticket { id status } errors
      }
    }
  GQL

  ASSIGN_TICKET = <<~GQL
    mutation AssignTicket($ticketId: ID!) {
      assignTicket(input: { ticketId: $ticketId }) {
        ticket { id status agent { name } } errors
      }
    }
  GQL

  describe "createTicket" do
    include_examples "requires authentication", CREATE_TICKET,
                     variables: { title: "T", description: "D" }

    it "allows a customer to create a ticket" do
      result = gql(CREATE_TICKET, variables: { title: "Help", description: "Details" },
                                  current_user: customer)
      expect(result.dig("data", "createTicket", "ticket", "status")).to eq("open")
    end

    it "denies an agent from creating a ticket" do
      result = gql(CREATE_TICKET, variables: { title: "T", description: "D" }, current_user: agent)
      expect(result.dig("errors")).to be_present
    end

    it "returns errors for missing title" do
      result = gql(CREATE_TICKET, variables: { title: "", description: "D" }, current_user: customer)
      expect(result.dig("data", "createTicket", "errors")).to be_present
    end

    it "returns errors when title exceeds 255 characters" do
      result = gql(CREATE_TICKET, variables: { title: "a" * 256, description: "D" },
                                  current_user: customer)
      expect(result.dig("data", "createTicket", "errors")).to be_present
    end
  end

  describe "tickets query" do
    include_examples "requires authentication", GET_TICKETS

    before { create_list(:ticket, 3, customer: customer) }

    it "returns only the customer's own tickets" do
      create(:ticket, customer: other_customer)
      result = gql(GET_TICKETS, current_user: customer)
      expect(result.dig("data", "tickets", "edges").size).to eq(3)
    end

    it "returns all tickets for an agent" do
      create(:ticket, customer: other_customer)
      result = gql(GET_TICKETS, current_user: agent)
      expect(result.dig("data", "tickets", "edges").size).to eq(4)
    end

    it "filters by status" do
      create(:ticket, :closed, customer: customer)
      result = gql(GET_TICKETS, variables: { status: "open" }, current_user: customer)
      statuses = result.dig("data", "tickets", "edges").map { |e| e.dig("node", "status") }
      expect(statuses).to all(eq("open"))
    end

    it "exposes totalCount" do
      result = gql(GET_TICKETS, current_user: customer)
      expect(result.dig("data", "tickets", "totalCount")).to eq(3)
    end

    describe "pagination" do
      before { create_list(:ticket, 7, customer: customer) }   # 10 total

      it "respects the first argument" do
        result = gql(GET_TICKETS, variables: { first: 4 }, current_user: customer)
        expect(result.dig("data", "tickets", "edges").size).to eq(4)
        expect(result.dig("data", "tickets", "pageInfo", "hasNextPage")).to be true
      end

      it "returns the next page using the endCursor" do
        page1  = gql(GET_TICKETS, variables: { first: 6 }, current_user: customer)
        cursor = page1.dig("data", "tickets", "pageInfo", "endCursor")

        page2 = gql(GET_TICKETS, variables: { first: 6, after: cursor }, current_user: customer)
        expect(page2.dig("data", "tickets", "edges").size).to eq(4)
        expect(page2.dig("data", "tickets", "pageInfo", "hasNextPage")).to be false
      end

      it "returns no duplicate nodes across pages" do
        page1  = gql(GET_TICKETS, variables: { first: 5 }, current_user: customer)
        cursor = page1.dig("data", "tickets", "pageInfo", "endCursor")
        page2  = gql(GET_TICKETS, variables: { first: 5, after: cursor }, current_user: customer)

        ids1 = page1.dig("data", "tickets", "edges").map { |e| e.dig("node", "id") }
        ids2 = page2.dig("data", "tickets", "edges").map { |e| e.dig("node", "id") }
        expect(ids1 & ids2).to be_empty
      end
    end
  end

  describe "ticket query" do
    let(:ticket) { create(:ticket, customer: customer) }

    include_examples "requires authentication", GET_TICKET, variables: { id: 0 }

    it "returns a ticket the customer owns" do
      result = gql(GET_TICKET, variables: { id: ticket.id }, current_user: customer)
      expect(result.dig("data", "ticket", "id")).to eq(ticket.id.to_s)
    end

    it "returns nil for a ticket the customer does not own" do
      other = create(:ticket, customer: other_customer)
      result = gql(GET_TICKET, variables: { id: other.id }, current_user: customer)
      expect(result.dig("data", "ticket")).to be_nil
    end

    it "allows an agent to view any ticket" do
      result = gql(GET_TICKET, variables: { id: ticket.id }, current_user: agent)
      expect(result.dig("data", "ticket", "id")).to eq(ticket.id.to_s)
    end
  end

  describe "closeTicket" do
    let(:ticket) { create(:ticket, customer: customer) }

    include_examples "requires authentication", CLOSE_TICKET,
                     variables: { ticketId: 0 }

    it "allows an agent to close a ticket" do
      result = gql(CLOSE_TICKET, variables: { ticketId: ticket.id },
                                  current_user: agent)
      expect(result.dig("data", "closeTicket", "ticket", "status")).to eq("closed")
    end

    it "allows a customer to close their own ticket" do
      result = gql(CLOSE_TICKET, variables: { ticketId: ticket.id },
                                  current_user: customer)
      expect(result.dig("data", "closeTicket", "ticket", "status")).to eq("closed")
    end
  end

  describe "assignTicket" do
    let(:ticket) { create(:ticket, customer: customer) }

    include_examples "requires authentication", ASSIGN_TICKET, variables: { ticketId: 0 }
    include_examples "agent only", ASSIGN_TICKET, variables: { ticketId: 0 }

    it "assigns the ticket to the calling agent and sets status to in_progress" do
      result = gql(ASSIGN_TICKET, variables: { ticketId: ticket.id }, current_user: agent)
      node = result.dig("data", "assignTicket", "ticket")
      expect(node["status"]).to eq("pending")
      expect(node.dig("agent", "name")).to eq(agent.name)
    end
  end
end
