require "rails_helper"

RSpec.describe TicketPolicy, type: :policy do
  let(:customer)       { create(:user) }
  let(:other_customer) { create(:user) }
  let(:agent)          { create(:user, :agent) }
  let(:ticket)         { create(:ticket, customer: customer) }

  describe "Scope" do
    let(:other_ticket) { create(:ticket, customer: other_customer) }

    it "returns all tickets for an agent" do
      scope = Pundit.policy_scope!(agent, Ticket)
      expect(scope).to include(ticket, other_ticket)
    end

    it "returns only own tickets for a customer" do
      scope = Pundit.policy_scope!(customer, Ticket)
      expect(scope).to contain_exactly(ticket)
    end
  end

  describe "#create?" do
    it "grants customers" do
      policy = described_class.new(customer, ticket)
      expect(policy.create?).to be true
    end

    it "denies agents" do
      policy = described_class.new(agent, ticket)
      expect(policy.create?).to be false
    end
  end

  describe "#show?" do
    it "allows owner and agents" do
      expect(described_class.new(customer, ticket).show?).to be true
      expect(described_class.new(agent, ticket).show?).to be true
    end

    it "denies other customers" do
      expect(described_class.new(other_customer, ticket).show?).to be false
    end
  end

  describe "#update?" do
    it "allows agents only" do
      expect(described_class.new(agent, ticket).update?).to be true
      expect(described_class.new(customer, ticket).update?).to be false
    end
  end

  describe "#destroy?" do
    it "denies everyone" do
      expect(described_class.new(customer, ticket).destroy?).to be false
      expect(described_class.new(agent, ticket).destroy?).to be false
    end
  end

  describe "#export?" do
    it "allows agents" do
      expect(described_class.new(agent, ticket).export?).to be true
      expect(described_class.new(customer, ticket).export?).to be false
    end
  end
end
