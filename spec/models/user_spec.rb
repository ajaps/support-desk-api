require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    it "rejects an invalid email format" do
      user.email = "not-an-email"
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it "requires password of at least 8 characters on create" do
      user.password = "short"
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "does not re-validate password length when password is unchanged" do
      user = create(:user)
      user.name = "New Name"
      expect(user).to be_valid
    end
  end

  describe "callbacks" do
    it "downcases the email before saving" do
      user = create(:user, email: "UPPER@EXAMPLE.COM")
      expect(user.reload.email).to eq("upper@example.com")
    end
  end

  describe "role helpers" do
    it "identifies customers" do
      expect(build(:user, role: "customer")).to be_customer
      expect(build(:user, role: "customer")).not_to be_agent
    end

    it "identifies agents" do
      expect(build(:user, :agent)).to be_agent
      expect(build(:user, :agent)).not_to be_customer
    end
  end

  describe "#authenticate" do
    let!(:user) { create(:user, password: "Password1!") }

    it "returns the user for a correct password" do
      expect(user.authenticate("Password1!")).to eq(user)
    end

    it "returns false for an incorrect password" do
      expect(user.authenticate("wrong")).to be_falsey
    end
  end
end
