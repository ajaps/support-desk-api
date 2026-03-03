require "rails_helper"

RSpec.describe "Comment mutations", type: :request do
  let(:customer)       { create(:user) }
  let(:other_customer) { create(:user) }
  let(:agent)          { create(:user, :agent) }
  let(:ticket)         { create(:ticket, customer: customer) }

  CREATE_COMMENT = <<~GQL
    mutation CreateComment($ticketId: ID!, $body: String!) {
      createComment(input: { ticketId: $ticketId, body: $body }) {
        comment { id body user { name role } }
        errors
      }
    }
  GQL

  include_examples "requires authentication", CREATE_COMMENT,
                   variables: { ticketId: 0, body: "hello" }

  context "when an agent comments" do
    it "succeeds on an open ticket" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "Looking into this." },
                   current_user: agent)
      expect(result.dig("data", "createComment", "comment", "body")).to eq("Looking into this.")
    end

    it "returns the agent role on the comment" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "On it." },
                   current_user: agent)
      expect(result.dig("data", "createComment", "comment", "user", "role")).to eq("agent")
    end

    it "returns errors for a blank body" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "" },
                   current_user: agent)
      expect(result.dig("data", "createComment", "errors")).to be_present
    end
  end

  context "when a customer comments before an agent has replied" do
    it "returns an authorization error" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "Hello?" },
                   current_user: customer)
      expect(result["errors"]).to be_present
    end
  end

  context "when a customer comments after an agent has replied" do
    before { create(:comment, ticket: ticket, user: agent) }

    it "allows the ticket owner to reply" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "Thanks!" },
                   current_user: customer)
      expect(result.dig("data", "createComment", "comment", "body")).to eq("Thanks!")
    end

    it "denies a different customer" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "Me too!" },
                   current_user: other_customer)
      expect(result["errors"]).to be_present
    end

    it "returns validation errors for a blank body" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "" },
                   current_user: customer)
      expect(result.dig("data", "createComment", "errors")).to be_present
    end
  end

  context "when the ticket is closed" do
    let(:ticket) { create(:ticket, :closed, customer: customer) }

    it "denies an agent from commenting" do
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "Follow up." },
                   current_user: agent)
      expect(result["errors"]).to be_present
    end

    it "denies the ticket owner from commenting" do
      create(:comment, ticket: ticket, user: agent)
      result = gql(CREATE_COMMENT,
                   variables:    { ticketId: ticket.id, body: "Is it resolved?" },
                   current_user: customer)
      expect(result["errors"]).to be_present
    end
  end
end
