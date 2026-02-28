require "rails_helper"

RSpec.describe Comment, type: :model do
  it "prevents a customer from commenting before an agent" do
    ticket   = create(:ticket)
    customer = ticket.customer
    comment  = build(:comment, ticket: ticket, user: customer)

    expect(comment).not_to be_valid
    expect(comment.errors[:base]).to include(/only comment after a support agent/)
  end

  it "prevent a customer from commenting on a ticket they don't own" do
    ticket   = create(:ticket)
    customer = create(:user)
    comment  = build(:comment, ticket: ticket, user: customer)
    expect(comment).not_to be_valid
    expect(comment.errors[:user]).to include("must be the ticket owner")
  end

  it "prevents a customer from commenting if the ticket is closed" do
    ticket   = create(:ticket, closed_at: Time.current)
    customer = ticket.customer
    comment  = build(:comment, ticket: ticket, user: customer)
    expect(comment).not_to be_valid
    expect(comment.errors[:base]).to include(/cannot comment on a closed ticket/)
  end

  it "allows a customer to comment after an agent has commented" do
    ticket  = create(:ticket)
    agent   = create(:user, :agent)
    create(:comment, ticket: ticket, user: agent)
    customer_comment = build(:comment, ticket: ticket, user: ticket.customer)
    expect(customer_comment).to be_valid
  end

  it "allows an agent to comment freely" do
    customer = create(:user)
    ticket = create(:ticket, customer: customer)
    agent  = create(:user, :agent)
    comment = build(:comment, ticket: ticket, user: agent)
    expect(comment).to be_valid
  end
end
