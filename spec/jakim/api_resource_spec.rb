# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jakim::ApiResource do
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

    def fake_response(query)
      url = URI.parse("https://www.e-solat.gov.my/index.php?#{query}")
      instance_double(Faraday::Env, url: url, response_headers: {})
    end

    it "computes the monthly expiry from the request's own year param, not the current year" do
      response = fake_response("period=month&zone=SGR01&month=2&year=2025")

      resource.send(:set_cache_header, :monthly, response)

      expect(response.response_headers["Expires"]).to eq(Date.new(2025, 2, 1).to_time.end_of_month.iso8601)
    end

    it "falls back to the current year for monthly when no year param is present" do
      response = fake_response("period=month&zone=SGR01&month=2")

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
      response = fake_response("period=year&zone=SGR01&year=2027")

      resource.send(:set_cache_header, :yearly, response)

      expect(response.response_headers["Expires"]).to eq(Date.new(2027, 12, 31).to_time.end_of_year.iso8601)
    end

    it "sets the islamic events expiry to the end of the current year" do
      response = fake_response("type=all")

      resource.send(:set_cache_header, :islamic_events, response)

      expect(response.response_headers["Expires"]).to eq(Time.current.end_of_year.iso8601)
    end
  end

  it "exposes the Expires header on a live (stubbed) request" do
    stub_request(:get, %r{\Ahttps://www\.e-solat\.gov\.my/index\.php})
      .to_return(status: 200, body: body, headers: headers)
    result = described_class.monthly(zone: "SGR01", month: 2, year: 2025)

    expect(result._headers["Expires"]).to eq(Date.new(2025, 2, 1).to_time.end_of_month.iso8601)
  end
end
