# frozen_string_literal: true

module Jakim
  class PrayerTime < Flexirest::Base
    base_url "https://www.e-solat.gov.my/index.php"

    get :daily, "", defaults: { r: "esolatApi/TakwimSolat", period: "today", zone: "SGR01" }
    get :monthly, "", defaults: { r: "esolatApi/TakwimSolat", period: "month", zone: "SGR01", month: Time.current.month }
    get :yearly, "", defaults: { r: "esolatApi/TakwimSolat", period: "year", zone: "SGR01", year: Time.current.year }
    # Mapped here so it shares the resource hooks, but exposed publicly via
    # Jakim::Calendar.islamic_events.
    get :islamic_events, "", defaults: { r: "esolatApi/islamicevent", type: "all" }

    before_request :set_user_agent
    before_request :upcase_zone
    after_request :set_cache_header

    private

    def set_user_agent(name, request)
      request.headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    end

    def upcase_zone(name, request)
      return unless request.get_params[:zone]

      request.get_params[:zone] = request.get_params[:zone].upcase
    end

    # `response` here is the Faraday response env passed to the after_request
    # callback (not our Flexirest::Request instance), so the request's query
    # params are recovered from the completed request URL rather than from a
    # shared class-level accessor (which would race across threads).
    def set_cache_header(name, response)
      params = response.url&.query ? URI.decode_www_form(response.url.query).to_h : {}

      expiry = case name
      when :daily
        Time.current.end_of_day
      when :monthly
        Date.new((params["year"].presence || Date.current.year).to_i, params["month"].to_i, 1).to_time.end_of_month
      when :yearly
        Date.new(params["year"].to_i, 12, 31).to_time.end_of_year
      when :islamic_events
        Time.current.end_of_year
      end

      response.response_headers["Expires"] = expiry.iso8601
    end
  end
end
