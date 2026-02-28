require "rails_helper"

RSpec.describe CommentPolicy, type: :policy do
  let(:customer) { create(:user) }
  let(:other_customer) { create(:user) }
  let(:agent) { create(:user, :agent) }
  let(:ticket) { create(:ticket, customer: customer) }

  describe "#create?" do
    context "when no agent has commented yet" do
      let(:comment) { build(:comment, ticket: ticket, user: customer) }

      it "denies the customer" do
        policy = described_class.new(customer, comment)
        expect(policy.create?).to be false
      end

      it "permits the agent" do
        comment = build(:comment, ticket: ticket, user: agent)
        policy = described_class.new(agent, comment)
        expect(policy.create?).to be true
      end
    end

    context "when an agent has already commented" do
      before { create(:comment, ticket: ticket, user: agent) }

      let(:comment) { build(:comment, ticket: ticket, user: customer) }

      it "permits the owning customer" do
        policy = described_class.new(customer, comment)
        expect(policy.create?).to be true
      end

      it "denies a different customer" do
        other_comment = build(:comment, ticket: ticket, user: other_customer)
        policy = described_class.new(other_customer, other_comment)
        expect(policy.create?).to be false
      end
    end
  end
end
