require "rails_helper"

RSpec.describe ExportTicketsJob, type: :job do
  let(:agent)  { create(:user, :agent) }
  let(:ticket) { create(:ticket, :closed) }

  let(:export) do
    Export.create!(
      agent:        agent,
      status:       :pending,
      export_type:  "recently_closed_tickets",
      filename:     "export_#{SecureRandom.hex(8)}.csv",
      ticket_array: [ ticket.id ].to_json
    )
  end

  before { ActionMailer::Base.deliveries.clear }

  describe "#perform" do
    it "attaches a CSV file to the export" do
      described_class.perform_now(export.id, agent.id)
      expect(export.reload.file).to be_attached
    end

    it "sets the export status to completed" do
      described_class.perform_now(export.id, agent.id)
      expect(export.reload.status).to eq("completed")
    end

    it "enqueues a delivery email to the requesting agent" do
      expect { described_class.perform_now(export.id, agent.id) }
        .to have_enqueued_mail(ExportMailer, :ready)
    end

    it "generates a CSV with the correct column headers" do
      described_class.perform_now(export.id, agent.id)
      content = export.reload.file.download
      expect(content).to include("ID,Title,Customer,Agent,Status,CreatedAt,ClosedAt")
    end

    it "includes a row for each ticket" do
      described_class.perform_now(export.id, agent.id)
      rows = CSV.parse(export.reload.file.download, headers: true)
      expect(rows.count).to eq(1)
      expect(rows.first["ID"].to_i).to eq(ticket.id)
    end

    context "when an error occurs mid-job" do
      let(:mailer_double) { instance_double(ActionMailer::MessageDelivery) }

      before do
        allow_any_instance_of(ActiveJob::Base).to receive(:retry_job).and_raise(StandardError, "smtp failure")
        allow(ExportMailer).to receive(:ready).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_later)
          .and_raise(StandardError, "smtp failure")
      end

      it "sets the export status to failed" do
        expect { described_class.perform_now(export.id, agent.id) }
          .to raise_error(StandardError, "smtp failure")
        expect(export.reload.status).to eq("failed")
      end

      it "persists the error message on the export" do
        expect { described_class.perform_now(export.id, agent.id) }
          .to raise_error(StandardError)
        expect(export.reload.error_message).to eq("smtp failure")
      end
    end
  end
end
