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
    ticket   = create(:ticket, closed_at: Time.current)
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
end
