require "rails_helper"

RSpec.describe ApplicationPolicy, type: :policy do
  let(:user)   { create(:user) }
  let(:record) { create(:ticket) }
  let(:policy) { described_class.new(user, record) }

  it "raises when user is nil" do
    expect { described_class.new(nil, record) }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "index? returns false by default" do
    expect(policy.index?).to be false
  end

  it "show? returns false by default" do
    expect(policy.show?).to be false
  end

  it "create? returns false by default" do
    expect(policy.create?).to be false
  end

  it "new? delegates to create?" do
    expect(policy.new?).to eq(policy.create?)
  end

  it "update? returns false by default" do
    expect(policy.update?).to be false
  end

  it "edit? delegates to update?" do
    expect(policy.edit?).to eq(policy.update?)
  end

  it "destroy? returns false by default" do
    expect(policy.destroy?).to be false
  end

  describe ApplicationPolicy::Scope do
    it "raises when user is nil" do
      expect { described_class.new(nil, Ticket.all) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "raises NotImplementedError when resolve is called on the base scope" do
      scope = described_class.new(user, Ticket.all)
      expect { scope.resolve }.to raise_error(NoMethodError)
    end
  end
end
