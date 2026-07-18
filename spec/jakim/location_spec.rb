# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jakim::Location do
  describe ".data" do
    it "has 219 frozen rows with the expected keys" do
      expect(described_class.data.size).to eq(219)
      expect(described_class.data).to be_frozen
      expect(described_class.data).to all(be_frozen)
      expect(described_class.data.first.keys).to contain_exactly(:state, :code, :location, :latitude, :longitude)
    end
  end

  describe ".all" do
    it "returns string-keyed copies" do
      row = described_class.all.first
      expect(row["code"]).to eq("JHR01")
      expect(row).not_to be_frozen
    end
  end

  describe ".zone" do
    it "merges sub-locations sharing a code into one row" do
      zone = described_class.zone("JHR01")
      expect(zone["code"]).to eq("JHR01")
      expect(zone["location"]).to include("Pulau Aur").and include("Pemanggil")
    end

    it "returns a row with empty location for an unknown code" do
      expect(described_class.zone("XXX99")["location"]).to eq("")
    end
  end

  describe ".find_by_name" do
    it "resolves a location slug" do
      expect(described_class.find_by_name("kuala-lumpur")).to eq("WLY01")
    end

    it "resolves a state name" do
      expect(described_class.find_by_name("Labuan")).to eq("WLY02")
    end

    it "returns nil for an unknown slug" do
      expect(described_class.find_by_name("atlantis")).to be_nil
    end
  end

  describe ".valid_name?" do
    it "is true for known and false for unknown" do
      expect(described_class.valid_name?("kuala-lumpur")).to be(true)
      expect(described_class.valid_name?("atlantis")).to be(false)
    end
  end

  describe ".codes" do
    it "returns unique zone codes" do
      codes = described_class.codes
      expect(codes).to include("JHR01", "WLY01", "WLY02")
      expect(codes.uniq).to eq(codes)
    end
  end

  describe ".nearest_zone" do
    it "returns a zone code and distance for KL coordinates" do
      code, dist = described_class.nearest_zone(3.139, 101.686)
      expect(code).to match(/\A[A-Z]{3}\d{2}\z/)
      expect(dist).to be_a(Float)
    end

    it "returns nil for invalid input" do
      expect(described_class.nearest_zone("abc", nil)).to be_nil
    end
  end
end
