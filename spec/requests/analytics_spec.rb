require "rails_helper"

RSpec.describe "Analytics queries", type: :request do
  let(:customer) { create(:user) }
  let(:agent)    { create(:user, :agent) }

  AVERAGE_RESPONSE_TIME = <<~GQL
    query {
      averageAgentResponseTime
    }
  GQL

  include_examples "requires authentication", AVERAGE_RESPONSE_TIME

  context "when a customer queries" do
    it "returns an authorization error" do
      result = gql(AVERAGE_RESPONSE_TIME, current_user: customer)
      expect(result["errors"].first["message"]).to match(/not authorized/i)
    end
  end

  context "when an agent queries" do
    context "with no agent replies yet" do
      before { create(:ticket, customer: customer) }

      it "returns null" do
        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to be_nil
      end
    end

    context "with one ticket that has an agent reply" do
      it "returns a human-readable duration string" do
        ticket = create(:ticket, customer: customer, created_at: 4.hours.ago)
        create(:comment, ticket: ticket, user: agent, created_at: 2.hours.ago)

        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to eq("2 hours")
      end
    end

    context "with multiple tickets" do
      it "averages the first-reply time across all tickets" do
        ticket1 = create(:ticket, customer: customer, created_at: 10.hours.ago)
        create(:comment, ticket: ticket1, user: agent, created_at: 8.hours.ago)  # 2h

        ticket2 = create(:ticket, customer: customer, created_at: 10.hours.ago)
        create(:comment, ticket: ticket2, user: agent, created_at: 6.hours.ago)  # 4h

        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to eq("3 hours")
      end

      it "uses only the first agent reply per ticket, ignoring later ones" do
        ticket = create(:ticket, customer: customer, created_at: 6.hours.ago)
        create(:comment, ticket: ticket, user: agent, created_at: 4.hours.ago)  # 2h response
        create(:comment, ticket: ticket, user: agent, created_at: 1.hour.ago)   # ignored

        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to eq("2 hours")
      end

      it "ignores customer comments when computing response time" do
        ticket = create(:ticket, customer: customer, created_at: 6.hours.ago)
        create(:comment, ticket: ticket, user: agent,    created_at: 2.hours.ago)  # 4h response
        create(:comment, ticket: ticket, user: customer, created_at: 5.hours.ago)  # ignored

        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to eq("4 hours")
      end

      it "excludes tickets with no agent reply from the average" do
        ticket1 = create(:ticket, customer: customer, created_at: 4.hours.ago)
        create(:comment, ticket: ticket1, user: agent,    created_at: 2.hours.ago)

        ticket2 = create(:ticket, customer: customer, created_at: 4.hours.ago)

        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to eq("2 hours")
      end

      it "uses singular 'hour' for exactly 1 hour" do
        ticket = create(:ticket, customer: customer, created_at: 2.hours.ago)
        create(:comment, ticket: ticket, user: agent, created_at: 1.hour.ago)

        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to eq("1 hour")
      end
    end

    context "when there are tickets from a previous month" do
      it "excludes them from the average" do
        # This month: 2h response
        ticket_now = create(:ticket, customer: customer, created_at: 4.hours.ago)
        create(:comment, ticket: ticket_now, user: agent, created_at: 2.hours.ago)

        # Last month: 10h response — should not be included
        last_month = Date.current.prev_month
        ticket_old = create(:ticket, customer: customer,
                            created_at: last_month.end_of_month - 5.hours)
        create(:comment, ticket: ticket_old, user: agent,
               created_at: last_month.end_of_month + 5.hours)

        result = gql(AVERAGE_RESPONSE_TIME, current_user: agent)
        expect(result.dig("data", "averageAgentResponseTime")).to eq("2 hours")
      end
    end
  end
end
