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

  describe ".nearest_in_zone" do
    # Shah Alam Seksyen 7. Shah Alam has no boundary polygon of its own — it
    # sits inside the Petaling district — so this is the coordinate Zone.detect
    # labels "Petaling" despite Shah Alam being a named SGR01 sub-location.
    let(:shah_alam) { [3.0700, 101.4900] }

    it "returns the closest sub-location of the zone" do
      location = described_class.nearest_in_zone("SGR01", *shah_alam)

      expect(location["location"]).to eq("Shah Alam")
      expect(location["state"]).to eq("Selangor")
    end

    it "still returns the neighbouring town when that one is closer" do
      # Petaling Jaya: ~4km from the Petaling centroid, ~12km from Shah Alam.
      expect(described_class.nearest_in_zone("SGR01", 3.1073, 101.6067)["location"])
        .to eq("Petaling")
    end

    it "never leaves the zone it was given" do
      # Klang is nearer to these coordinates than any SGR01 row, but it is SGR03.
      expect(described_class.nearest_in_zone("SGR01", 3.0449, 101.4455)["code"]).to eq("SGR01")
    end

    it "accepts string coordinates" do
      expect(described_class.nearest_in_zone("SGR01", "3.0700", "101.4900")["location"])
        .to eq("Shah Alam")
    end

    it "returns nil for an unknown code" do
      expect(described_class.nearest_in_zone("XXX99", *shah_alam)).to be_nil
    end

    it "returns nil for invalid coordinates" do
      expect(described_class.nearest_in_zone("SGR01", "abc", nil)).to be_nil
    end
  end

  describe ".find_in_zone" do
    it "finds a sub-location by name, ignoring case and surrounding space" do
      expect(described_class.find_in_zone("SGR01", " shah alam ")["location"]).to eq("Shah Alam")
    end

    it "returns nil when the name belongs to another zone" do
      expect(described_class.find_in_zone("JHR01", "Shah Alam")).to be_nil
    end

    it "returns nil for a name that is a state rather than a sub-location" do
      expect(described_class.find_in_zone("JHR01", "Johor")).to be_nil
    end

    it "returns nil for a blank name" do
      expect(described_class.find_in_zone("SGR01", nil)).to be_nil
      expect(described_class.find_in_zone("SGR01", "  ")).to be_nil
    end
  end
end
