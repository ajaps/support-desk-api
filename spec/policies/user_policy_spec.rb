require "rails_helper"

RSpec.describe UserPolicy, type: :policy do
  let(:agent)         { create(:user, :agent) }
  let(:customer)      { create(:user) }
  let(:other_customer) { create(:user) }

  describe "#show?" do
    it "allows a user to see their own profile" do
      expect(described_class.new(customer, customer).show?).to be true
    end

    it "denies a customer from seeing another user's profile" do
      expect(described_class.new(customer, other_customer).show?).to be false
    end

    it "allows an agent to see any user" do
      expect(described_class.new(agent, customer).show?).to be true
    end
  end
end
