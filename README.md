# Jakim

Ruby client for Malaysia's JAKIM [e-Solat](https://www.e-solat.gov.my) prayer times service, built on [Flexirest](https://github.com/andyjeffries/flexirest). Ships the full zone dataset, hijri calendar helpers, and zone-boundary polygons for GPS detection.

## Installation

```ruby
gem "jakim"
```

## Usage

### Prayer times (`Jakim::PrayerTime`)

```ruby
Jakim::PrayerTime.daily(zone: "WLY01")                         # today's prayer times
Jakim::PrayerTime.monthly(zone: "SGR01", month: 2, year: 2025) # every day of a month
Jakim::PrayerTime.yearly(zone: "JHR01", year: 2025)            # every day of a year
```

Results are Flexirest objects mirroring the e-Solat JSON (`result.prayerTime`, `result.status`, ...). Zone codes are upcased automatically. Each response carries an `Expires` header (`result._headers["Expires"]`) computed from the requested period — end of day for `daily`, end of the requested month/year for `monthly`/`yearly` — useful for HTTP caching.

A browser `User-Agent` is sent on every request; e-Solat blocks default HTTP clients.

### Zones and locations (`Jakim::Location`)

All 219 JAKIM sub-locations with state, zone code, and coordinates — no network calls.

```ruby
Jakim::Location.all                        # every row, string keys
Jakim::Location.codes                      # unique zone codes: ["JHR01", ..., "WLY02"]
Jakim::Location.zone("JHR01")              # one merged row per zone ("Pulau Aur, Pemanggil")
Jakim::Location.find_by_name("kuala-lumpur") # slug or state name => "WLY01"
Jakim::Location.valid_name?("atlantis")    # => false

Jakim::Location.nearest_zone(3.139, 101.686)
# => ["SGR01", 4.36]   (zone code, distance in km to nearest zone centroid)

Jakim::Location.nearest_in_zone("SGR01", 3.07, 101.49)
# => { "state" => "Selangor", "code" => "SGR01", "location" => "Shah Alam", ... }

Jakim::Location.find_in_zone("SGR01", "shah alam")
# => the same row; nil when the name belongs to another zone or names no
#    sub-location at all (a state label, say)
```

`nearest_zone` returns `nil` for invalid coordinates. Note the example: central Kuala Lumpur resolves to SGR01 because Selangor's centroid happens to be closer — a centroid-averaging artifact. Use `Jakim::Zone.detect` when border accuracy matters.

`nearest_in_zone` answers the other half of "where am I": a zone code covers several towns at once — SGR01 alone spans Gombak, Hulu Selangor, Rawang, Hulu Langat, Sepang, Petaling and Shah Alam — so a resolved zone still needs a name. Pair it with `Jakim::Zone.detect`, whose polygons are administrative *districts*: Shah Alam has none of its own and sits inside Petaling, so a coordinate there detects as `"Petaling"` until `nearest_in_zone` re-labels it.

### GPS zone detection (`Jakim::Zone`)

Point-in-polygon detection against the bundled zone boundary GeoJSON — accurate near zone borders where `nearest_zone`'s centroid heuristic can pick a neighbour.

```ruby
Jakim::Zone.detect(3.139003, 101.686855)
# => { "code" => "WLY01", "name" => "W.P. Kuala Lumpur", "state" => "KUL" }

Jakim::Zone.detect(0.0, 90.0)   # outside Malaysia
# => nil

Jakim::Zone.geojson_path        # path to the bundled jakim.geojson (~0.8 MB)
```

String coordinates (e.g. request params) are accepted. Recommended pattern: `detect` first, fall back to `Jakim::Location.nearest_zone` for points outside every polygon (coastal waters, islands), then name whichever code you land on with `Jakim::Location.nearest_in_zone`. The polygon properties carry names and states of their own (`"W.P. Kuala Lumpur"`, `"KUL"`) that appear nowhere in `Location.all`, so re-labelling also keeps detection speaking the same vocabulary as the location list.

### Hijri calendar (`Jakim::Calendar`)

Helpers over the raw JAKIM feeds. Methods return raw JAKIM day hashes (string keys) — reshape for your UI as needed.

```ruby
Jakim::Calendar.hijri_month(zone: "WLY01", hijri_year: 1447, hijri_month: 7)
# => all days of Rejab 1447, deduped and sorted, even when the month
#    spans two gregorian years (fetches both yearly feeds)

Jakim::Calendar.today_hijri(zone: "WLY01")  # => [1448, 1]
Jakim::Calendar.parse_hijri("1447-08-16")   # => [1447, 8]

Jakim::Calendar.islamic_events              # peristiwa penting
# => { "event" => [...] }
```

## Errors

The gem raises on network/API failures — rescue at your application boundary. `Jakim::Location` and `Jakim::Zone` are pure data (no network); they return `nil` for invalid input instead of raising.

## Development

```
bundle install
bundle exec rspec
```

## License

MIT
