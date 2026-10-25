# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jakim::Zone do
  describe ".geojson_path" do
    it "points at the bundled geojson" do
      expect(File).to exist(described_class.geojson_path)
      expect(File.size(described_class.geojson_path)).to be > 500_000
    end
  end

  describe ".detect" do
    it "resolves central Kuala Lumpur to WLY01 by polygon containment" do
      result = described_class.detect(3.139003, 101.686855)
      expect(result).to include("code" => "WLY01")
      expect(result["state"]).to be_a(String)
    end

    it "resolves Kota Tinggi (Johor) coordinates to a JHR zone" do
      result = described_class.detect(1.729375, 103.899227)
      expect(result["code"]).to start_with("JHR")
    end

    # JAKIM's PHG07 is Mukim Rompin, Endau and Pontian. The polygons are by
    # district, so the whole of Rompin district, Muadzam Shah included, is
    # PHG07 until mukim outlines replace it.
    it "resolves Rompin district to PHG07" do
      expect(described_class.detect(2.805810, 103.488504)).to include("code" => "PHG07", "name" => "Rompin")
    end

    it "resolves Bukit Mabong, split out of Kapit district, to SWK04 like Kapit" do
      feature = JSON.parse(File.read(File.expand_path("../../data/jakim.geojson", __dir__)))["features"]
        .find { |f| f["properties"]["name"] == "Bukit Mabong" }
      expect(feature["properties"]["jakim_code"]).to eq("SWK04")
    end

    it "returns nil for open ocean far from Malaysia" do
      expect(described_class.detect(0.0, 90.0)).to be_nil
    end

    it "returns nil for invalid input" do
      expect(described_class.detect("abc", nil)).to be_nil
    end

    it "accepts string coordinates (as delivered by request params)" do
      result = described_class.detect("3.139003", "101.686855")
      expect(result["code"]).to eq("WLY01")
    end
  end
end
