# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jakim::Calendar do
  describe ".parse_hijri" do
    it "splits a hijri date string into [year, month]" do
      expect(described_class.parse_hijri("1447-08-16")).to eq([1447, 8])
    end

    it "handles nil safely" do
      expect(described_class.parse_hijri(nil)).to eq([nil, nil])
    end
  end

  describe ".hijri_month" do
    def day(date, hijri)
      { "date" => date, "day" => "Monday", "hijri" => hijri, "fajr" => "05:50:00" }
    end

    def stub_yearly(year, days)
      stub_request(:get, %r{\Ahttps://www\.e-solat\.gov\.my/index\.php})
        .with(query: hash_including("period" => "year", "year" => year.to_s))
        .to_return(
          status: 200,
          body: { "prayerTime" => days, "status" => "OK!" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "collects a hijri month that straddles two gregorian years, deduped and hijri-sorted" do
      # Hijri 1447-07 estimate: (1447*0.970229+621.567).floor = 2025.
      # Put days out of order and duplicated across the two feeds.
      stub_yearly(2025, [
        day("30-Dec-2025", "1447-07-10"),
        day("31-Dec-2025", "1447-07-11"),
        day("01-Dec-2025", "1447-06-29") # other month, filtered out
      ])
      stub_yearly(2026, [
        day("01-Jan-2026", "1447-07-12"),
        day("31-Dec-2025", "1447-07-11"), # duplicate of first feed
        day("05-Feb-2026", "1447-08-17") # other month, filtered out
      ])

      days = described_class.hijri_month(zone: "WLY01", hijri_year: 1447, hijri_month: 7)

      expect(days.map { |d| d["hijri"] }).to eq(["1447-07-10", "1447-07-11", "1447-07-12"])
      expect(days.map { |d| d["date"] }).to eq(["30-Dec-2025", "31-Dec-2025", "01-Jan-2026"])
    end
  end

  describe ".islamic_events" do
    it "returns the parsed events hash" do
      stub_request(:get, %r{\Ahttps://www\.e-solat\.gov\.my/index\.php})
        .with(query: hash_including("r" => "esolatApi/islamicevent", "type" => "all"))
        .to_return(
          status: 200,
          body: { "event" => [{ "tarikh_miladi" => "27-Jun-2026" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      events = described_class.islamic_events
      expect(events["event"].first["tarikh_miladi"]).to eq("27-Jun-2026")
    end
  end

  describe ".today_hijri" do
    it "returns today's hijri [year, month] from the daily feed" do
      stub_request(:get, %r{\Ahttps://www\.e-solat\.gov\.my/index\.php})
        .with(query: hash_including("period" => "today"))
        .to_return(
          status: 200,
          body: { "prayerTime" => [{ "date" => "19-Jul-2026", "hijri" => "1448-01-04" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect(described_class.today_hijri(zone: "WLY01")).to eq([1448, 1])
    end
  end
end
