# frozen_string_literal: true

module Jakim
  # Hijri calendar helpers over the raw JAKIM feeds. Methods return raw JAKIM
  # day hashes (string keys: "date", "day", "hijri", prayer times) — reshaping
  # for a UI is the caller's concern.
  module Calendar
    # All days of a hijri month. A hijri month spans gregorian year
    # boundaries, so we pull the two gregorian years it can overlap and
    # filter by hijri year/month.
    def self.hijri_month(zone:, hijri_year:, hijri_month:)
      g = (hijri_year * 0.970229 + 621.567).floor
      (yearly_days(zone, g) + yearly_days(zone, g + 1))
        .select { |d| hy, hm = parse_hijri(d["hijri"]); hy == hijri_year && hm == hijri_month }
        .uniq { |d| d["date"] }
        # Sort by hijri [year, month, day] — locale-proof (JAKIM's gregorian
        # date uses Malay month abbreviations that Date.parse can't read).
        .sort_by { |d| d["hijri"].to_s.split("-").map(&:to_i) }
    end

    # Islamic events (peristiwa penting) for the year, as a parsed hash:
    # { "event" => [...] }. Raises on network/API failure.
    def self.islamic_events
      PrayerTime.islamic_events.as_json
    end

    # Today's hijri [year, month] for the zone.
    def self.today_hijri(zone:)
      payload = PrayerTime.daily(zone: zone).as_json
      day = Array(payload["prayerTime"]).first || {}
      parse_hijri(day["hijri"])
    end

    # "1447-08-16" => [1447, 8]
    def self.parse_hijri(hijri)
      y, m, = hijri.to_s.split("-").map(&:to_i)
      [y, m]
    end

    def self.yearly_days(zone, year)
      Array(PrayerTime.yearly(zone: zone, year: year).as_json["prayerTime"])
    end
    private_class_method :yearly_days
  end
end
