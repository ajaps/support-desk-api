require "rails_helper"

RSpec.describe TokenService do
  let(:user) { create(:user) }

  describe ".encode" do
    subject(:token) { described_class.encode(user) }

    it "returns a non-empty JWT string" do
      expect(token).to be_a(String).and be_present
    end

    it "encodes the user id in the payload" do
      payload = described_class.decode(token)
      expect(payload["sub"]).to eq(user.id)
    end

    it "encodes the user role in the payload" do
      payload = described_class.decode(token)
      expect(payload["role"]).to eq(user.role)
    end

    it "includes an expiry claim" do
      payload = described_class.decode(token)
      expect(payload["exp"]).to be_within(5).of(24.hours.from_now.to_i)
    end

    it "includes a unique jti for each token" do
      t1 = described_class.encode(user)
      t2 = described_class.encode(user)
      expect(described_class.decode(t1)["jti"]).not_to eq(described_class.decode(t2)["jti"])
    end
  end

  describe ".decode" do
    it "decodes a valid token" do
      token   = described_class.encode(user)
      payload = described_class.decode(token)
      expect(payload["sub"]).to eq(user.id)
    end

    it "raises AuthenticationError for a tampered token" do
      token = described_class.encode(user) + "tampered"
      expect { described_class.decode(token) }.to raise_error(AuthenticationError, /invalid token/i)
    end

    it "raises AuthenticationError for an expired token" do
      token = described_class.encode(user)
      travel_to(25.hours.from_now) do
        expect { described_class.decode(token) }.to raise_error(AuthenticationError, /expired/i)
      end
    end

    it "raises AuthenticationError for a blank token" do
      expect { described_class.decode("") }.to raise_error(AuthenticationError)
    end
  end
end