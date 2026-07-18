# frozen_string_literal: true

require "json"

module Jakim
  # GPS -> JAKIM zone resolution via point-in-polygon against the zone
  # boundary MultiPolygons bundled in data/jakim.geojson. More accurate near
  # borders than Location.nearest_zone's centroid heuristic.
  module Zone
    def self.geojson_path
      File.expand_path("../../data/jakim.geojson", __dir__)
    end

    # Returns { "code" =>, "name" =>, "state" => } for the zone containing
    # the point, or nil if no polygon contains it (outside Malaysia).
    def self.detect(latitude, longitude)
      lat = Float(latitude)
      lng = Float(longitude)

      features.each do |feature|
        geometry = feature["geometry"]
        # Normalize: the dataset mixes MultiPolygon and Polygon features.
        polygons = geometry["type"] == "Polygon" ? [geometry["coordinates"]] : geometry["coordinates"]
        next unless in_multi_polygon?(lat, lng, polygons)

        props = feature["properties"]
        return { "code" => props["jakim_code"], "name" => props["name"], "state" => props["state"] }
      end
      nil
    rescue ArgumentError, TypeError
      nil
    end

    def self.features
      @features ||= JSON.parse(File.read(geojson_path))["features"].freeze
    end
    private_class_method :features

    def self.in_multi_polygon?(lat, lng, multi_polygon)
      multi_polygon.any? do |polygon|
        # Inside the exterior ring and not inside any hole.
        in_ring?(lat, lng, polygon[0]) && polygon[1..].none? { |hole| in_ring?(lat, lng, hole) }
      end
    end
    private_class_method :in_multi_polygon?

    # Ray-casting. ring is [lng, lat] pairs (GeoJSON coordinate order).
    def self.in_ring?(lat, lng, ring)
      inside = false
      j = ring.length - 1
      ring.each_with_index do |(xi, yi), i|
        xj, yj = ring[j]
        if (yi > lat) != (yj > lat) && lng < (xj - xi) * (lat - yi) / (yj - yi) + xi
          inside = !inside
        end
        j = i
      end
      inside
    end
    private_class_method :in_ring?
  end
end
