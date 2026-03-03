require "rails_helper"

RSpec.describe OpenTicketsMailer, type: :mailer do
  describe "#ready" do
    let(:agent)  { create(:user, :agent) }
    let(:export) { create(:export, :with_file, agent: agent) }

    before do
      ActiveStorage::Current.url_options = { host: "test.host", protocol: "http" }
      ActionMailer::Base.deliveries.clear
    end

    subject(:mail) { described_class.ready(agent, export) }

    it "sends to the correct recipient" do
      expect(mail.to).to eq([ agent.email ])
    end

    it "sets the correct from address" do
      expect(mail.from).to eq([ "no-reply@support-desk.com" ])
    end

    it "includes the date in the subject" do
      expect(mail.subject).to include(Date.today.strftime("%B %d, %Y"))
    end

    it "includes 'Daily Open Tickets' in the subject" do
      expect(mail.subject).to include("Daily Open Tickets")
    end
  end
end
