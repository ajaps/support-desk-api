require "rails_helper"

RSpec.describe "Export mutations", type: :request do
  include ActiveJob::TestHelper

  let(:customer) { create(:user) }
  let(:agent)    { create(:user, :agent) }

  EXPORT_CLOSED_TICKETS = <<~GQL
    mutation {
      exportRecentlyClosedTickets(input: {}) {
        id message success
      }
    }
  GQL

  include_examples "requires authentication", EXPORT_CLOSED_TICKETS

  context "when a customer calls" do
    it "returns a not-authorized GraphQL error" do
      result = gql(EXPORT_CLOSED_TICKETS, current_user: customer)
      expect(result.dig("errors", 0, "message")).to match(/not authorized/i)
    end

    it "does not create an Export record" do
      expect { gql(EXPORT_CLOSED_TICKETS, current_user: customer) }
        .not_to change(Export, :count)
    end
  end

  context "when an agent calls" do
    it "returns success: true" do
      result = gql(EXPORT_CLOSED_TICKETS, current_user: agent)
      expect(result.dig("data", "exportRecentlyClosedTickets", "success")).to be true
    end

    it "includes a confirmation message" do
      result = gql(EXPORT_CLOSED_TICKETS, current_user: agent)
      expect(result.dig("data", "exportRecentlyClosedTickets", "message")).to include("email")
    end

    it "creates a pending Export record" do
      expect { gql(EXPORT_CLOSED_TICKETS, current_user: agent) }
        .to change(Export, :count).by(1)
      expect(Export.last.status).to eq("pending")
    end

    it "enqueues an ExportTicketsJob" do
      expect { gql(EXPORT_CLOSED_TICKETS, current_user: agent) }
        .to have_enqueued_job(ExportTicketsJob)
    end

    it "returns the export id" do
      result = gql(EXPORT_CLOSED_TICKETS, current_user: agent)
      expect(result.dig("data", "exportRecentlyClosedTickets", "id")).to eq(Export.last.id.to_s)
    end

    it "rejects a second request within the cooldown period" do
      gql(EXPORT_CLOSED_TICKETS, current_user: agent)
      result = gql(EXPORT_CLOSED_TICKETS, current_user: agent)
      expect(result.dig("data", "exportRecentlyClosedTickets", "success")).to be false
      expect(result.dig("data", "exportRecentlyClosedTickets", "message")).to be_present
    end
  end
end
