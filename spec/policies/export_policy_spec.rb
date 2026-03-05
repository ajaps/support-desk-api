require "rails_helper"

RSpec.describe ExportPolicy, type: :policy do
  let(:agent)       { create(:user, :agent) }
  let(:other_agent) { create(:user, :agent) }
  let(:customer)    { create(:user) }
  let(:export)      { create(:export, agent: agent) }

  describe "#show?" do
    it "allows the owning agent to see their export" do
      expect(described_class.new(agent, export).show?).to be true
    end

    it "denies a different agent from seeing another agent's export" do
      expect(described_class.new(other_agent, export).show?).to be false
    end

    it "denies a customer" do
      expect(described_class.new(customer, export).show?).to be false
    end
  end
end
