# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jakim::PrayerTime do
  let(:body) { { "status" => "OK!", "prayerTime" => [] }.to_json }
  let(:headers) { { "Content-Type" => "application/json" } }

  def stub_esolat
    stub_request(:get, %r{\Ahttps://www\.e-solat\.gov\.my/index\.php}).to_return(status: 200, body: body, headers: headers)
  end

  describe "endpoints" do
    it "requests daily prayer times with today period" do
      stub = stub_esolat
      described_class.daily(zone: "WLY01")

      expect(stub).to have_been_requested
      expect(WebMock).to have_requested(:get, "https://www.e-solat.gov.my/index.php")
        .with(query: hash_including("r" => "esolatApi/TakwimSolat", "period" => "today", "zone" => "WLY01"))
    end

    it "requests monthly prayer times with month period" do
      stub_esolat
      described_class.monthly(zone: "SGR01", month: 2, year: 2025)

      expect(WebMock).to have_requested(:get, "https://www.e-solat.gov.my/index.php")
        .with(query: hash_including("period" => "month", "month" => "2", "year" => "2025"))
    end

    it "requests yearly prayer times with year period" do
      stub_esolat
      described_class.yearly(zone: "SGR01", year: 2025)

      expect(WebMock).to have_requested(:get, "https://www.e-solat.gov.my/index.php")
        .with(query: hash_including("period" => "year", "year" => "2025"))
    end

    it "requests islamic events" do
      stub_esolat
      described_class.islamic_events

      expect(WebMock).to have_requested(:get, "https://www.e-solat.gov.my/index.php")
        .with(query: hash_including("r" => "esolatApi/islamicevent", "type" => "all"))
    end

    it "upcases the zone param" do
      stub_esolat
      described_class.daily(zone: "wly01")

      expect(WebMock).to have_requested(:get, "https://www.e-solat.gov.my/index.php")
        .with(query: hash_including("zone" => "WLY01"))
    end

    it "sends a browser User-Agent (e-Solat blocks default clients)" do
      stub_esolat
      described_class.daily

      expect(WebMock).to have_requested(:get, "https://www.e-solat.gov.my/index.php")
        .with(headers: { "User-Agent" => /Mozilla/ }, query: hash_including("period" => "today"))
    end

    it "parses the JSON body into the result" do
      stub_esolat
      result = described_class.daily(zone: "SGR01")

      expect(result.status).to eq("OK!")
    end
  end

  # `set_cache_header` is exercised directly because it's a private
  # after_request callback that computes the `Expires` header from the
  # completed request's query string (Faraday response env).
  describe "#set_cache_header" do
    subject(:resource) { described_class.new }

    def fake_response(query, rows: [ { "date" => "01-Feb-2025" } ])
      url = URI.parse("https://www.e-solat.gov.my/index.php?#{query}")
      instance_double(Faraday::Env, url: url, response_headers: {}, body: { "prayerTime" => rows }.to_json)
    end

    it "computes the monthly expiry from the request's own year param, not the current year" do
      response = fake_response("period=month&zone=SGR01&month=2&year=2025")

      resource.send(:set_cache_header, :monthly, response)

      expect(response.response_headers["Expires"]).to eq(Date.new(2025, 2, 1).to_time.end_of_month.iso8601)
    end

    it "falls back to the current year for monthly when no year param is present" do
      response = fake_response("period=month&zone=SGR01&month=2",
                               rows: [ { "date" => "01-Feb-#{Date.current.year}" } ])

      resource.send(:set_cache_header, :monthly, response)

      expected = Date.new(Date.current.year, 2, 1).to_time.end_of_month.iso8601
      expect(response.response_headers["Expires"]).to eq(expected)
    end

    it "sets the daily expiry to the end of today regardless of query params" do
      response = fake_response("period=today&zone=SGR01")

      resource.send(:set_cache_header, :daily, response)

      expect(response.response_headers["Expires"]).to eq(Time.current.end_of_day.iso8601)
    end

    it "sets the yearly expiry to the end of the requested year" do
      response = fake_response("period=year&zone=SGR01&year=2027", rows: [ { "date" => "01-Jan-2027" } ])

      resource.send(:set_cache_header, :yearly, response)

      expect(response.response_headers["Expires"]).to eq(Date.new(2027, 12, 31).to_time.end_of_year.iso8601)
    end

    it "sets no monthly expiry when e-Solat answers with another year" do
      response = fake_response("period=month&zone=SGR01&month=1&year=2027", rows: [ { "date" => "01-Jan-2026" } ])

      resource.send(:set_cache_header, :monthly, response)

      expect(response.response_headers).not_to have_key("Expires")
    end

    it "sets no yearly expiry when e-Solat answers with another year" do
      response = fake_response("period=year&zone=SGR01&year=2027", rows: [ { "date" => "01-Jan-2026" } ])

      resource.send(:set_cache_header, :yearly, response)

      expect(response.response_headers).not_to have_key("Expires")
    end

    it "sets no monthly expiry for an empty answer" do
      response = fake_response("period=month&zone=SGR01&month=2&year=2025", rows: [])

      resource.send(:set_cache_header, :monthly, response)

      expect(response.response_headers).not_to have_key("Expires")
    end

    it "sets no monthly expiry when the body is not JSON" do
      url = URI.parse("https://www.e-solat.gov.my/index.php?period=month&zone=SGR01&month=2&year=2025")
      response = instance_double(Faraday::Env, url: url, response_headers: {}, body: "not json")

      resource.send(:set_cache_header, :monthly, response)

      expect(response.response_headers).not_to have_key("Expires")
    end

    it "sets the islamic events expiry to the end of the current year" do
      response = fake_response("type=all")

      resource.send(:set_cache_header, :islamic_events, response)

      expect(response.response_headers["Expires"]).to eq(Time.current.end_of_year.iso8601)
    end
  end

  it "exposes the Expires header on a live (stubbed) request" do
    stub_request(:get, %r{\Ahttps://www\.e-solat\.gov\.my/index\.php})
      .to_return(status: 200, headers: headers,
                 body: { "status" => "OK!", "prayerTime" => [ { "date" => "01-Feb-2025" } ] }.to_json)
    result = described_class.monthly(zone: "SGR01", month: 2, year: 2025)

    expect(result._headers["Expires"]).to eq(Date.new(2025, 2, 1).to_time.end_of_month.iso8601)
  end

  describe "Flexirest caching" do
    # Flexirest 1.13.2 ignores `cache_store = nil` (its `and return` fires
    # before the assignment), so the store is cleared with _reset_caching!.
    around do |ex|
      Flexirest::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
      Flexirest::Base.perform_caching = true
      ex.run
    ensure
      Flexirest::Base._reset_caching!
    end

    def stub_rows(date)
      stub_request(:get, %r{\Ahttps://www\.e-solat\.gov\.my/index\.php})
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: { "status" => "OK!", "prayerTime" => [ { "date" => date } ] }.to_json)
    end

    # The month asked for is the current one: a past month's Expires date is
    # already gone, and Flexirest rightly does not store such an answer.
    it "serves a right-year answer from the cache" do
      stub = stub_rows(Date.current.strftime("%d-%b-%Y"))
      2.times { described_class.monthly(zone: "SGR01", month: Date.current.month, year: Date.current.year) }

      expect(stub).to have_been_requested.once
    end

    it "asks again after a wrong-year answer" do
      stub = stub_rows("01-Jan-#{Date.current.year}")
      2.times { described_class.monthly(zone: "SGR01", month: 1, year: Date.current.year + 1) }

      expect(stub).to have_been_requested.twice
    end
  end
end
