# Jakim

Ruby client for Malaysia's JAKIM [e-Solat](https://www.e-solat.gov.my) prayer times API, built on [Flexirest](https://github.com/andyjeffries/flexirest).

## Installation

```ruby
gem "jakim"
```

## Usage

```ruby
Jakim::ApiResource.daily(zone: "WLY01")                       # today's prayer times
Jakim::ApiResource.monthly(zone: "SGR01", month: 2, year: 2025)
Jakim::ApiResource.yearly(zone: "JHR01", year: 2025)
Jakim::ApiResource.islamic_events
```

Results are Flexirest objects mirroring the e-Solat JSON (`result.prayerTime`, `result.status`, ...). Zone codes are upcased automatically. Each response carries an `Expires` header (`result._headers["Expires"]`) computed from the requested period — end of day for `daily`, end of the requested month/year for `monthly`/`yearly` — useful for HTTP caching.

A browser `User-Agent` is sent on every request; e-Solat blocks default HTTP clients.

## Development

```
bundle install
bundle exec rspec
```

## License

MIT
