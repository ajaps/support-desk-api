require "rails_helper"

RSpec.describe DailyTicketReminderJob, type: :job do
  let!(:agent1) { create(:user, :agent) }
  let!(:agent2) { create(:user, :agent) }
  let!(:open_ticket)   { create(:ticket) }
  let!(:closed_ticket) { create(:ticket, :closed) }

  before { ActionMailer::Base.deliveries.clear }

  describe "#perform" do
    it "creates one Export record" do
      expect { described_class.perform_now }
        .to change(Export, :count).by(1)
    end

    it "creates the export with status completed" do
      described_class.perform_now
      expect(Export.last.status).to eq("completed")
    end

    it "attaches a CSV file to the export" do
      described_class.perform_now
      expect(Export.last.file).to be_attached
    end

    it "generates CSV headers for open tickets" do
      described_class.perform_now
      content = Export.last.file.download
      expect(content).to include("ID,Title,Customer,Agent,Status,CreatedAt")
    end

    it "includes only open tickets in the CSV" do
      described_class.perform_now
      rows = CSV.parse(Export.last.file.download, headers: true)
      expect(rows.count).to eq(1)
      expect(rows.first["ID"].to_i).to eq(open_ticket.id)
    end

    it "enqueues one email per agent" do
      expect { described_class.perform_now }
        .to have_enqueued_mail(OpenTicketsMailer, :ready).exactly(User.agent.count).times
    end
  end
end
