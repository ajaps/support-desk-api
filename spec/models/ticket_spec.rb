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
      recent  = create(:ticket, closed_at: 2.weeks.ago, status: "closed")
      _old    = create(:ticket, closed_at: 2.months.ago, status: "closed")
      expect(Ticket.recently_closed).to contain_exactly(recent)
    end
  end

  describe "attachment validations" do
    it "allows PNG attachment" do
      ticket = build(:ticket)
      ticket.file.attach(
        io:           StringIO.new("fake"),
        filename:     "image.png",
        content_type: "image/png"
      )
      expect(ticket).to be_valid
    end

    it "allows JPEG attachment" do
      ticket = build(:ticket)
      ticket.file.attach(
        io:           StringIO.new("fake"),
        filename:     "photo.jpg",
        content_type: "image/jpeg"
      )
      expect(ticket).to be_valid
    end

    it "allows GIF attachment" do
      ticket = build(:ticket)
      ticket.file.attach(
        io:           StringIO.new("fake"),
        filename:     "anim.gif",
        content_type: "image/gif"
      )
      expect(ticket).to be_valid
    end

    it "allows PDF attachment" do
      ticket = build(:ticket)
      ticket.file.attach(
        io:           StringIO.new("fake"),
        filename:     "doc.pdf",
        content_type: "application/pdf"
      )
      expect(ticket).to be_valid
    end

    it "rejects disallowed content types" do
      ticket = build(:ticket)
      ticket.file.attach(
        io:           StringIO.new("fake"),
        filename:     "doc.exe",
        content_type: "application/x-msdownload"
      )
      expect(ticket).not_to be_valid
      expect(ticket.errors[:file]).to be_present
    end

    it "rejects files larger than 4 MB" do
      ticket = build(:ticket)
      ticket.file.attach(
        io:           StringIO.new("x" * (4.megabytes + 1)),
        filename:     "big.png",
        content_type: "image/png"
      )
      expect(ticket).not_to be_valid
      expect(ticket.errors[:file]).to be_present
    end
  end

  describe "#close!" do
    let(:ticket) { create(:ticket) }

    it "sets closed_at to the current time" do
      freeze_time do
        ticket.close!
        expect(ticket.reload.closed_at).to eq(Time.current)
      end
    end

    it "returns false for may_close? when already closed" do
      ticket.update!(closed_at: 1.hour.ago, status: "closed")
      expect(ticket.may_close?).to be false
    end
  end

  describe "#closed?" do
    it "returns false for an open ticket" do
      expect(build(:ticket, closed_at: nil).closed?).to be false
    end

    it "returns true for a closed ticket" do
      expect(build(:ticket, :closed).closed?).to be true
    end
  end

  describe "#status" do
    it "returns 'open' for an open ticket" do
      expect(build(:ticket).status).to eq("open")
    end

    it "returns 'closed' for a closed ticket" do
      expect(build(:ticket, :closed).status).to eq("closed")
    end
  end

  describe "#agent_comments" do
    let(:ticket)   { create(:ticket) }
    let(:agent)    { create(:user, :agent) }
    let(:customer) { ticket.customer }

    it "returns only comments made by agents" do
      agent_comment     = create(:comment, ticket: ticket, user: agent)
      _customer_comment = create(:comment, ticket: ticket, user: customer)
      expect(ticket.agent_comments).to contain_exactly(agent_comment)
    end

    it "returns an empty collection when no agent has commented" do
      expect(ticket.agent_comments).to be_empty
    end
  end
end
