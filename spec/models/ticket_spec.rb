require "rails_helper"

RSpec.describe Ticket, type: :model do
  subject(:ticket) { build(:ticket) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }

    it "rejects a customer field set to an agent user" do
      ticket = build(:ticket, customer: build(:user, :agent))
      expect(ticket).not_to be_valid
      expect(ticket.errors[:customer]).to include("must be a customer")
    end

    it "rejects an agent field set to a customer user" do
      ticket = build(:ticket, agent: build(:user))

      expect(ticket).not_to be_valid
      expect(ticket.errors[:agent]).to include("must be an agent")
    end

    it "allows agent to be nil" do
      ticket = build(:ticket, agent: nil)
      expect(ticket).to be_valid
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

  describe "attachment validations" do
    it "allows PNG attachments" do
      ticket = build(:ticket)
      ticket.attachments.attach(
        io:           StringIO.new("fake"),
        filename:     "image.png",
        content_type: "image/png"
      )
      expect(ticket).to be_valid
    end

    it "rejects disallowed content types" do
      ticket = build(:ticket)
      ticket.attachments.attach(
        io:           StringIO.new("fake"),
        filename:     "doc.exe",
        content_type: "application/x-msdownload"
      )
      expect(ticket).not_to be_valid
      expect(ticket.errors[:attachments]).to be_present
    end
  end
end
