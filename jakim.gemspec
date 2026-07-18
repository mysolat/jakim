# frozen_string_literal: true

require_relative "lib/jakim/version"

Gem::Specification.new do |spec|
  spec.name = "jakim"
  spec.version = Jakim::VERSION
  spec.authors = ["Mohd Khairi"]
  spec.email = ["khairi.ad6@gmail.com"]

  spec.summary = "Ruby client for the JAKIM e-Solat prayer times API"
  spec.description = "Flexirest-based client for Malaysia's JAKIM e-Solat service " \
                     "(www.e-solat.gov.my): daily/monthly/yearly prayer times and islamic events."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb", "data/jakim.geojson", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "flexirest", "~> 1.12"
end
