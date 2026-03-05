require "rails_helper"

RSpec.describe Comment, type: :model do
  it { is_expected.to validate_presence_of(:body) }
  it { is_expected.to validate_length_of(:body).is_at_most(5000) }

  it "prevents a customer from commenting before an agent" do
    ticket   = create(:ticket)
    customer = ticket.customer

    expect {
      create(:comment, ticket: ticket, user: customer)
    }.to raise_error(ActiveRecord::RecordInvalid, /only comment after a support agent/)
  end

  it "prevent a customer from commenting on a ticket they don't own" do
    ticket   = create(:ticket)
    customer = create(:user)
    expect {
      create(:comment, ticket: ticket, user: customer)
    }.to raise_error(ActiveRecord::RecordInvalid, /must be the ticket owner/)
  end

  it "prevents a customer from commenting if the ticket is closed" do
    ticket   = create(:ticket, closed_at: Time.current, status: "closed")
    customer = ticket.customer
    expect {
      create(:comment, ticket: ticket, user: customer)
    }.to raise_error(ActiveRecord::RecordInvalid, /Customers cannot comment on a closed ticket/)
  end

  it "allows a customer to comment after an agent has commented" do
    ticket  = create(:ticket)
    agent   = create(:user, :agent)
    create(:comment, ticket: ticket, user: agent)
    expect {
      create(:comment, ticket: ticket, user: ticket.customer)
    }.not_to raise_error
  end

  it "allows an agent to comment freely" do
    customer = create(:user)
    ticket = create(:ticket, customer: customer)
    agent  = create(:user, :agent)
    comment = build(:comment, ticket: ticket, user: agent)
    expect(comment).to be_valid
  end

  describe "state machine transitions" do
    let(:ticket)   { create(:ticket) }
    let(:agent)    { create(:user, :agent) }
    let(:customer) { ticket.customer }

    it "transitions ticket to awaiting_customer when agent comments" do
      create(:comment, ticket: ticket, user: agent)
      expect(ticket.reload.status).to eq("awaiting_customer")
    end

    it "sets agent_replied_at on the first agent comment" do
      expect { create(:comment, ticket: ticket, user: agent) }
        .to change { ticket.reload.agent_replied_at }.from(nil)
    end

    it "does not overwrite agent_replied_at on subsequent agent comments" do
      create(:comment, ticket: ticket, user: agent)
      first_replied_at = ticket.reload.agent_replied_at
      create(:comment, ticket: ticket, user: agent)
      expect(ticket.reload.agent_replied_at).to eq(first_replied_at)
    end

    it "transitions ticket to awaiting_agent when customer comments after agent" do
      create(:comment, ticket: ticket, user: agent)
      create(:comment, ticket: ticket, user: customer)
      expect(ticket.reload.status).to eq("awaiting_agent")
    end

    it "does not change status when agent comments on a closed ticket" do
      ticket.update!(closed_at: Time.current, status: "closed")
      create(:comment, ticket: ticket, user: agent)
      expect(ticket.reload.status).to eq("closed")
    end
  end
end
