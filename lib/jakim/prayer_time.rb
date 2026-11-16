# frozen_string_literal: true

require "json"

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
        year = (params["year"].presence || Date.current.year).to_i
        Date.new(year, params["month"].to_i, 1).to_time.end_of_month if rows_in_year?(response, year)
      when :yearly
        year = params["year"].to_i
        Date.new(year, 12, 31).to_time.end_of_year if rows_in_year?(response, year)
      when :islamic_events
        Time.current.end_of_year
      end

      # No Expires of ours leaves e-Solat's own, which is in the past, so
      # Flexirest does not store the answer.
      response.response_headers["Expires"] = expiry.iso8601 if expiry
    end

    # e-Solat ignores the year it is asked for and answers with the current
    # one: January 2027 asked for in 2026 comes back as January 2026. Kept
    # until the end of the period asked for, that answer would be served all
    # through it. So only an answer whose every row is in the requested year
    # is cached. An empty answer is not cached either: it is what an
    # unpublished period looks like, and caching it would hide the publish.
    def rows_in_year?(response, year)
      rows = JSON.parse(response.body.to_s)["prayerTime"]
      rows.is_a?(Array) && rows.any? &&
        rows.all? { |row| row.is_a?(Hash) && row["date"].to_s.end_with?("-#{year}") }
    rescue JSON::ParserError
      false
    end
  end
end
