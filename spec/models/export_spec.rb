require "rails_helper"

RSpec.describe Export, type: :model do
  let(:agent) { create(:user, :agent) }

  describe "associations" do
    it { is_expected.to have_one_attached(:file) }
  end

  describe "validations" do
    subject { build(:export, agent: agent) }

    it { is_expected.to validate_presence_of(:export_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:agent) }

    it "validates uniqueness of pending export per agent" do
      create(:export, :pending, agent: agent)

      duplicate = build(:export, :pending, agent: agent)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to include("Agent already has a pending export")
    end

    it "prevents an agent from exporting more than once within 5 minutes" do
      create(:export, agent: agent)

      too_soon = build(:export, agent: agent)

      expect(too_soon).not_to be_valid
      expect(too_soon.errors[:base]).to include("You have recently exported tickets. Please wait before exporting again.")
    end

    it "allows an export after the cooldown window has passed" do
      create(:export, agent: agent, created_at: 6.minutes.ago)

      expect(build(:export, agent: agent)).to be_valid
    end

    it "rejects ticket_array that is not valid JSON" do
      export = build(:export, agent: agent, ticket_array: "not json{{")
      expect(export).not_to be_valid
      expect(export.errors[:ticket_array]).to include("must be valid JSON")
    end

    it "accepts ticket_array that is valid JSON" do
      export = build(:export, agent: agent, ticket_array: "[1,2,3]")
      expect(export).to be_valid
    end
  end

  describe "#presigned_url" do
    before do
      ActiveStorage::Current.url_options = {
        host: "test.host",
        protocol: "http"
      }
    end

    context "when file is attached" do
      let(:export) { create(:export, :with_file, agent: agent) }

      it "returns a url" do
        expect(export.presigned_url).to include("http://test.host")
      end
    end

    context "when file is not attached" do
      let(:export) { create(:export, agent: agent, file: nil) }

      it "returns nil" do
        expect(export.presigned_url).to be_nil
      end
    end
  end
end
