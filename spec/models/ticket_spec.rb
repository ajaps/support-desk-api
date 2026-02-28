require "rails_helper"

RSpec.describe Ticket, type: :model do
  subject(:ticket) { build(:ticket) }

  describe "validations" do
    it "is invalid when title is not present/blank" do
      ticket = build(:ticket, title: "")
      expect(ticket).not_to be_valid
      expect(ticket.errors[:title]).to include("can't be blank")
    end

    it "is invalid when description is not present/blank" do
      ticket = build(:ticket, description: "")
      expect(ticket).not_to be_valid
      expect(ticket.errors[:description]).to include("can't be blank")
    end


    it "is invalid when a ticket is created without a customer" do
      ticket = build(:ticket, customer: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:customer]).to include("must exist")
    end

    it "is invalid when a ticket is created by an agent" do
      agent = create(:user, :agent)
      ticket = build(:ticket, customer: agent)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:customer]).to include("must be a customer")
    end
  end

  describe "scopes" do
    it ".open_tickets returns only open tickets" do
      open_ticket   = create(:ticket)
      _closed       = create(:ticket, :closed)
      expect(Ticket.open_tickets).to contain_exactly(open_ticket)
    end

    it ".recently_closed returns tickets closed within 1 month" do
      recent  = create(:ticket, closed_at: 2.weeks.ago)
      _old    = create(:ticket, closed_at: 2.months.ago)
      expect(Ticket.recently_closed).to contain_exactly(recent)
    end
  end
end
