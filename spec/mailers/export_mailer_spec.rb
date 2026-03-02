require "rails_helper"

RSpec.describe ExportMailer, type: :mailer do
  describe "#ready" do
    let(:agent) { create(:user, :agent) }
    before do
      ActiveStorage::Current.url_options = {
        host: "test.host",
        protocol: "http"
      }

      ActionMailer::Base.deliveries.clear
    end

    context "with attached file" do
      let(:export) { create(:export, :with_file, agent: agent) }

      def mail
        described_class.ready(agent, export)
      end

      it "sends to the correct recipient" do
        expect(mail.to).to eq([ agent.email ])
      end

      it "sets the correct subject" do
        expect(mail.subject).to include("Your closed tickets export is ready")
      end

      it "does not attach the file" do
        expect(mail.attachments).to be_empty
      end

      it "includes a download link in the body" do
        html_body = mail.html_part&.body&.decoded || mail.body.decoded

        expect(html_body).to include(export.file.filename.to_s)
        expect(html_body).to include("rails/active_storage")
      end

      it "delivers successfully" do
        expect { mail.deliver_now }
          .to change(ActionMailer::Base.deliveries, :count)
          .by(1)
      end
    end

    context "when file is not attached" do
      let(:export) { create(:export, agent: agent) }

      it "raises an error" do
        expect {
          described_class.ready(agent, export).deliver_now
        }.to raise_error("Export file not attached")
      end
    end
  end
end
