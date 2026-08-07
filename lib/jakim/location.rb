# frozen_string_literal: true

module Jakim
  # JAKIM prayer-time zones and their sub-locations (state, zone code,
  # location name, centroid coordinates). Ported from solat.my.
  module Location
    def self.all
      data.map { |l| l.transform_keys(&:to_s) }
    end

    # One merged row per zone code: `location` becomes the comma-joined list
    # of all sub-locations sharing the code.
    def self.zone(code)
      rows = all.select { |l| l["code"] == code }
      location = rows.first&.dup || {}
      location["location"] = rows.map { |l| l["location"] }.join(", ")
      location
    end

    # Slug ("kota-tinggi" / "Johor") -> zone code, matching by location
    # name first, then state name.
    def self.find_by_name(slug)
      name = slug.to_s.tr("-", " ").downcase
      data.find { |l| l[:location].downcase == name }&.dig(:code) ||
        data.find { |l| l[:state].downcase == name }&.dig(:code)
    end

    def self.valid_name?(slug)
      !find_by_name(slug).nil?
    end

    def self.codes
      data.map { |l| l[:code] }.uniq
    end

    # Returns the zone code whose centroid is geographically closest to the
    # given coordinates, along with the distance in kilometres.
    #
    #   zone, dist = Jakim::Location.nearest_zone(3.139, 101.686)
    #   # => ["WLY01", 0.82]
    #
    # Returns nil if the data is empty or coordinates are invalid.
    def self.nearest_zone(latitude, longitude)
      lat = Float(latitude)
      lon = Float(longitude)

      # Build per-zone centroid from all sub-locations sharing a code.
      centroids = data
        .group_by { |l| l[:code] }
        .transform_values do |locs|
          avg_lat = locs.sum { |l| l[:latitude].to_f } / locs.size
          avg_lon = locs.sum { |l| l[:longitude].to_f } / locs.size
          [avg_lat, avg_lon]
        end

      best_code = nil
      best_dist = Float::INFINITY

      centroids.each do |code, (clat, clon)|
        d = haversine(lat, lon, clat, clon)
        if d < best_dist
          best_dist = d
          best_code = code
        end
      end

      [best_code, best_dist.round(2)]
    rescue ArgumentError, TypeError
      nil
    end

    # The sub-location of `code` closest to the point.
    #
    #   Jakim::Location.nearest_in_zone("SGR01", 3.07, 101.49)
    #   # => { "state" => "Selangor", "code" => "SGR01", "location" => "Shah Alam", ... }
    #
    # A zone code covers several towns at once — SGR01 alone spans Gombak,
    # Hulu Selangor, Rawang, Hulu Langat, Sepang, Petaling and Shah Alam — so
    # resolving a zone only half-answers "where am I". Use this to name the
    # answer: Zone.detect reports the *administrative district* containing a
    # point, and Shah Alam has no district of its own (it sits inside
    # Petaling), so a coordinate there is labelled "Petaling" without it.
    #
    # Returns nil for an unknown code or non-numeric coordinates.
    def self.nearest_in_zone(code, latitude, longitude)
      lat = Float(latitude)
      lon = Float(longitude)

      all.select { |l| l["code"] == code }
         .min_by { |l| haversine(lat, lon, l["latitude"].to_f, l["longitude"].to_f) }
    rescue ArgumentError, TypeError
      nil
    end

    # The row for an exact zone + location-name pair, so a remembered name can
    # be turned back into the coordinates it was chosen for. Case- and
    # surrounding-space-insensitive; nil when the name belongs to another zone
    # or names no sub-location at all (a state label, say).
    def self.find_in_zone(code, name)
      name = name.to_s.strip
      return nil if name.empty?

      all.find { |l| l["code"] == code && l["location"].casecmp?(name) }
    end

    # Haversine great-circle distance in kilometres between two GPS points.
    def self.haversine(lat1, lon1, lat2, lon2)
      r = 6371.0
      phi1 = lat1 * Math::PI / 180
      phi2 = lat2 * Math::PI / 180
      dphi = (lat2 - lat1) * Math::PI / 180
      dlam = (lon2 - lon1) * Math::PI / 180
      a = Math.sin(dphi / 2)**2 + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dlam / 2)**2
      r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end
    private_class_method :haversine

    DATA = [
    { state: "Johor", code: "JHR01", location: "Pulau Aur", latitude: "2.444152", longitude: "104.524746" }.freeze,
    { state: "Johor", code: "JHR01", location: "Pemanggil", latitude: "2.580882", longitude: "104.326827" }.freeze,
    { state: "Johor", code: "JHR02", location: "Kota Tinggi", latitude: "1.729375", longitude: "103.899227" }.freeze,
    { state: "Johor", code: "JHR02", location: "Mersing", latitude: "2.430917", longitude: "103.836115" }.freeze,
    { state: "Johor", code: "JHR02", location: "Johor Bahru", latitude: "1.492659", longitude: "103.741359" }.freeze,
    { state: "Johor", code: "JHR03", location: "Kluang", latitude: "2.030068", longitude: "103.318464" }.freeze,
    { state: "Johor", code: "JHR03", location: "Pontian", latitude: "1.485561", longitude: "103.387859" }.freeze,
    { state: "Johor", code: "JHR04", location: "Batu Pahat", latitude: "1.849442", longitude: "102.928834" }.freeze,
    { state: "Johor", code: "JHR04", location: "Muar", latitude: "2.048817", longitude: "102.571553" }.freeze,
    { state: "Johor", code: "JHR04", location: "Segamat", latitude: "2.503460", longitude: "102.820754" }.freeze,
    { state: "Johor", code: "JHR04", location: "Gemas", latitude: "2.581593", longitude: "102.612488" }.freeze,
    { state: "Kedah", code: "KDH01", location: "Kota Setar", latitude: "6.096953", longitude: "100.353977" }.freeze,
    { state: "Kedah", code: "KDH01", location: "Kubang Pasu", latitude: "6.267335", longitude: "100.425831" }.freeze,
    { state: "Kedah", code: "KDH01", location: "Pokok Sena", latitude: "6.167317", longitude: "100.519358" }.freeze,
    { state: "Kedah", code: "KDH02", location: "Pendang", latitude: "5.993039", longitude: "100.477339" }.freeze,
    { state: "Kedah", code: "KDH02", location: "Kuala Muda", latitude: "5.644561", longitude: "100.489023" }.freeze,
    { state: "Kedah", code: "KDH02", location: "Yan", latitude: "5.794950", longitude: "100.372658" }.freeze,
    { state: "Kedah", code: "KDH03", location: "Padang Terap", latitude: "6.256764", longitude: "100.611034" }.freeze,
    { state: "Kedah", code: "KDH03", location: "Sik", latitude: "5.818345", longitude: "100.743021" }.freeze,
    { state: "Kedah", code: "KDH04", location: "Baling", latitude: "5.675547", longitude: "100.916814" }.freeze,
    { state: "Kedah", code: "KDH05", location: "Kulim", latitude: "5.371742", longitude: "100.555337" }.freeze,
    { state: "Kedah", code: "KDH05", location: "Bandar Bahru", latitude: "5.131163", longitude: "100.495534" }.freeze,
    { state: "Kedah", code: "KDH06", location: "Langkawi", latitude: "6.350000", longitude: "99.800000" }.freeze,
    { state: "Kedah", code: "KDH07", location: "Gunung Jerai", latitude: "5.783333", longitude: "100.433333" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Kota Bahru", latitude: "6.116786", longitude: "102.277684" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Bachok", latitude: "6.069586", longitude: "102.397185" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Pasir Puteh", latitude: "5.836163", longitude: "102.407741" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Tumpat", latitude: "6.199069", longitude: "102.169372" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Pasir Mas", latitude: "6.042412", longitude: "102.142782" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Tanah Merah", latitude: "5.808887", longitude: "102.147077" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Machang", latitude: "5.767933", longitude: "102.215387" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Kuala Krai", latitude: "5.530813", longitude: "102.201851" }.freeze,
    { state: "Kelantan", code: "KTN01", location: "Mukim Chiku", latitude: "4.916993", longitude: "102.177656" }.freeze,
    { state: "Kelantan", code: "KTN02", location: "Jeli", latitude: "5.700699", longitude: "101.843151" }.freeze,
    { state: "Kelantan", code: "KTN02", location: "Gua Musang", latitude: "4.884279", longitude: "101.968178" }.freeze,
    { state: "Kelantan", code: "KTN02", location: "Mukim Galas", latitude: "4.828924", longitude: "101.934807" }.freeze,
    { state: "Kelantan", code: "KTN02", location: "Bertam", latitude: "5.151936", longitude: "102.043792" }.freeze,
    { state: "Melaka", code: "MLK01", location: "Bandar Melaka", latitude: "2.197138", longitude: "102.249070" }.freeze,
    { state: "Melaka", code: "MLK01", location: "Alor Gajah", latitude: "2.382211", longitude: "102.211561" }.freeze,
    { state: "Melaka", code: "MLK01", location: "Jasin", latitude: "2.311337", longitude: "102.430923" }.freeze,
    { state: "Melaka", code: "MLK01", location: "Masjid Tanah", latitude: "2.352279", longitude: "102.108926" }.freeze,
    { state: "Melaka", code: "MLK01", location: "Merlimau", latitude: "2.145214", longitude: "102.422383" }.freeze,
    { state: "Melaka", code: "MLK01", location: "Nyalas", latitude: "2.436091", longitude: "102.469871" }.freeze,
    { state: "Negeri Sembilan", code: "NGS01", location: "Jempol", latitude: "2.896577", longitude: "102.405454" }.freeze,
    { state: "Negeri Sembilan", code: "NGS01", location: "Tampin", latitude: "2.472971", longitude: "102.231194" }.freeze,
    { state: "Negeri Sembilan", code: "NGS02", location: "Kuala Pilah", latitude: "2.740474", longitude: "102.248872" }.freeze,
    { state: "Negeri Sembilan", code: "NGS02", location: "Jelebu", latitude: "2.941072", longitude: "102.071910" }.freeze,
    { state: "Negeri Sembilan", code: "NGS02", location: "Rembau", latitude: "2.590525", longitude: "102.092986" }.freeze,
    { state: "Negeri Sembilan", code: "NGS03", location: "Port Dickson", latitude: "2.522540", longitude: "101.796293" }.freeze,
    { state: "Negeri Sembilan", code: "NGS03", location: "Seremban", latitude: "2.725889", longitude: "101.937824" }.freeze,
    { state: "Pahang", code: "PHG01", location: "Pulau Tioman", latitude: "2.790249", longitude: "104.169846" }.freeze,
    { state: "Pahang", code: "PHG02", location: "Kuantan", latitude: "3.816667", longitude: "103.333333" }.freeze,
    { state: "Pahang", code: "PHG02", location: "Pekan", latitude: "3.492095", longitude: "103.389545" }.freeze,
    { state: "Pahang", code: "PHG02", location: "Rompin", latitude: "2.688626", longitude: "102.522802" }.freeze,
    { state: "Pahang", code: "PHG02", location: "Muadzam Shah", latitude: "3.056192", longitude: "103.085225" }.freeze,
    { state: "Pahang", code: "PHG03", location: "Maran", latitude: "3.583380", longitude: "102.779065" }.freeze,
    { state: "Pahang", code: "PHG03", location: "Chenor", latitude: "3.493743", longitude: "102.581850" }.freeze,
    { state: "Pahang", code: "PHG03", location: "Temerloh", latitude: "3.448649", longitude: "102.416348" }.freeze,
    { state: "Pahang", code: "PHG03", location: "Bera", latitude: "3.270526", longitude: "102.453864" }.freeze,
    { state: "Pahang", code: "PHG03", location: "Jerantut", latitude: "3.937395", longitude: "102.362038" }.freeze,
    { state: "Pahang", code: "PHG04", location: "Bentong", latitude: "3.522168", longitude: "101.910353" }.freeze,
    { state: "Pahang", code: "PHG04", location: "Raub", latitude: "3.793532", longitude: "101.857465" }.freeze,
    { state: "Pahang", code: "PHG04", location: "Kuala Lipis", latitude: "4.184330", longitude: "102.054232" }.freeze,
    { state: "Pahang", code: "PHG05", location: "Genting Sempah", latitude: "3.350000", longitude: "101.783333" }.freeze,
    { state: "Pahang", code: "PHG05", location: "Janda Baik", latitude: "3.350000", longitude: "101.883333" }.freeze,
    { state: "Pahang", code: "PHG05", location: "Bukit Tinggi", latitude: "3.400997", longitude: "101.846822" }.freeze,
    { state: "Pahang", code: "PHG06", location: "Bukit Fraser", latitude: "3.711868", longitude: "101.736556" }.freeze,
    { state: "Pahang", code: "PHG06", location: "Genting Highlands", latitude: "3.423978", longitude: "101.793201" }.freeze,
    { state: "Pahang", code: "PHG06", location: "Cameron Highlands", latitude: "4.472120", longitude: "101.380144" }.freeze,
    { state: "Pahang", code: "PHG03", location: "Jengka", latitude: "3.723779", longitude: "102.545654" }.freeze,
    { state: "Perak", code: "PRK01", location: "Tapah", latitude: "4.197730", longitude: "101.261529" }.freeze,
    { state: "Perak", code: "PRK01", location: "Slim River", latitude: "3.830025", longitude: "101.404645" }.freeze,
    { state: "Perak", code: "PRK01", location: "Tanjung Malim", latitude: "3.705842", longitude: "101.504916" }.freeze,
    { state: "Perak", code: "PRK02", location: "Ipoh", latitude: "4.597479", longitude: "101.090106" }.freeze,
    { state: "Perak", code: "PRK02", location: "Batu Gajah", latitude: "4.472081", longitude: "101.041240" }.freeze,
    { state: "Perak", code: "PRK02", location: "Kampar", latitude: "4.308504", longitude: "101.153653" }.freeze,
    { state: "Perak", code: "PRK02", location: "Sungai Siput", latitude: "4.819012", longitude: "101.073718" }.freeze,
    { state: "Perak", code: "PRK02", location: "Kuala Kangsar", latitude: "4.773595", longitude: "100.942045" }.freeze,
    { state: "Perak", code: "PRK03", location: "Pengkalan Hulu", latitude: "5.706440", longitude: "100.999837" }.freeze,
    { state: "Perak", code: "PRK03", location: "Grik", latitude: "5.428454", longitude: "101.129703" }.freeze,
    { state: "Perak", code: "PRK03", location: "Lenggong", latitude: "5.108440", longitude: "100.968034" }.freeze,
    { state: "Perak", code: "PRK04", location: "Temengor", latitude: "5.333186", longitude: "101.367712" }.freeze,
    { state: "Perak", code: "PRK04", location: "Belum", latitude: "5.740126", longitude: "101.479350" }.freeze,
    { state: "Perak", code: "PRK05", location: "Teluk Intan", latitude: "4.022424", longitude: "101.020625" }.freeze,
    { state: "Perak", code: "PRK05", location: "Bagan Datuk", latitude: "3.991910", longitude: "100.786148" }.freeze,
    { state: "Perak", code: "PRK05", location: "Kampung Gajah", latitude: "4.184167", longitude: "100.938719" }.freeze,
    { state: "Perak", code: "PRK05", location: "Seri Iskandar", latitude: "4.357145", longitude: "100.963392" }.freeze,
    { state: "Perak", code: "PRK05", location: "Beruas", latitude: "4.500804", longitude: "100.781508" }.freeze,
    { state: "Perak", code: "PRK05", location: "Parit", latitude: "4.476689", longitude: "100.909749" }.freeze,
    { state: "Perak", code: "PRK05", location: "Lumut", latitude: "4.236302", longitude: "100.632220" }.freeze,
    { state: "Perak", code: "PRK05", location: "Sitiawan", latitude: "4.216825", longitude: "100.697824" }.freeze,
    { state: "Perak", code: "PRK05", location: "Pulau Pangkor", latitude: "4.227491", longitude: "100.557741" }.freeze,
    { state: "Perak", code: "PRK06", location: "Selama", latitude: "5.218462", longitude: "100.693460" }.freeze,
    { state: "Perak", code: "PRK06", location: "Taiping", latitude: "4.851932", longitude: "100.741634" }.freeze,
    { state: "Perak", code: "PRK06", location: "Bagan Serai", latitude: "5.008062", longitude: "100.539430" }.freeze,
    { state: "Perak", code: "PRK06", location: "Parit Buntar", latitude: "5.118682", longitude: "100.488016" }.freeze,
    { state: "Perak", code: "PRK07", location: "Bukit Larut", latitude: "4.862300", longitude: "100.793000" }.freeze,
    { state: "Perlis", code: "PLS01", location: "Kangar", latitude: "6.440633", longitude: "100.198371" }.freeze,
    { state: "Perlis", code: "PLS01", location: "Padang Besar", latitude: "6.662622", longitude: "100.321665" }.freeze,
    { state: "Perlis", code: "PLS01", location: "Arau", latitude: "6.429708", longitude: "100.269847" }.freeze,
    { state: "Pulau Pinang", code: "PNG01", location: "Pulau Pinang", latitude: "5.414168", longitude: "100.328759" }.freeze,
    { state: "Sabah", code: "SBH01", location: "Sandakan Timur", latitude: "5.839444", longitude: "118.117173" }.freeze,
    { state: "Sabah", code: "SBH01", location: "Bukit Garam", latitude: "5.500122", longitude: "117.837606" }.freeze,
    { state: "Sabah", code: "SBH01", location: "Semawang", latitude: "5.916667", longitude: "117.766666" }.freeze,
    { state: "Sabah", code: "SBH01", location: "Temanggong", latitude: "4.910632", longitude: "114.934834" }.freeze,
    { state: "Sabah", code: "SBH01", location: "Tambisan", latitude: "5.450148", longitude: "119.109986" }.freeze,
    { state: "Sabah", code: "SBH02", location: "Pinangah", latitude: "4.990731", longitude: "116.832411" }.freeze,
    { state: "Sabah", code: "SBH02", location: "Terusan", latitude: "6.426081", longitude: "117.687599" }.freeze,
    { state: "Sabah", code: "SBH02", location: "Beluran", latitude: "5.702070", longitude: "117.401544" }.freeze,
    { state: "Sabah", code: "SBH02", location: "Kuamut", latitude: "5.015856", longitude: "117.353107" }.freeze,
    { state: "Sabah", code: "SBH02", location: "Telupid", latitude: "5.627233", longitude: "117.127534" }.freeze,
    { state: "Sabah", code: "SBH03", location: "Lahad Datu", latitude: "5.024206", longitude: "118.330746" }.freeze,
    { state: "Sabah", code: "SBH03", location: "Kunak", latitude: "4.686116", longitude: "118.251146" }.freeze,
    { state: "Sabah", code: "SBH03", location: "Silabukan", latitude: "5.136667", longitude: "118.614167" }.freeze,
    { state: "Sabah", code: "SBH03", location: "Tungku", latitude: "4.931209", longitude: "114.911622" }.freeze,
    { state: "Sabah", code: "SBH03", location: "Sahabat", latitude: "5.078867", longitude: "119.070775" }.freeze,
    { state: "Sabah", code: "SBH03", location: "Semporna", latitude: "4.479391", longitude: "118.611545" }.freeze,
    { state: "Sabah", code: "SBH04", location: "Bandar Tawau", latitude: "4.244651", longitude: "117.891186" }.freeze,
    { state: "Sabah", code: "SBH04", location: "Balong", latitude: "4.398421", longitude: "118.058604" }.freeze,
    { state: "Sabah", code: "SBH04", location: "Merotai", latitude: "4.356929", longitude: "117.827169" }.freeze,
    { state: "Sabah", code: "SBH04", location: "Kalabakan", latitude: "4.411679", longitude: "117.492699" }.freeze,
    { state: "Sabah", code: "SBH05", location: "Kudat", latitude: "6.886840", longitude: "116.825311" }.freeze,
    { state: "Sabah", code: "SBH05", location: "Kota Marudu", latitude: "6.465705", longitude: "116.726409" }.freeze,
    { state: "Sabah", code: "SBH05", location: "Pitas", latitude: "6.722237", longitude: "117.055273" }.freeze,
    { state: "Sabah", code: "SBH05", location: "Pulau Banggi", latitude: "7.267260", longitude: "117.150005" }.freeze,
    { state: "Sabah", code: "SBH06", location: "Gunung Kinabalu", latitude: "6.074544", longitude: "116.562720" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Papar", latitude: "5.734628", longitude: "115.931851" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Ranau", latitude: "5.953561", longitude: "116.663950" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Kota Belud", latitude: "6.353248", longitude: "116.427877" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Tuaran", latitude: "6.176269", longitude: "116.232790" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Penampang", latitude: "5.914199", longitude: "116.107663" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Kota Kinabalu", latitude: "5.980408", longitude: "116.073457" }.freeze,
    { state: "Sabah", code: "SBH08", location: "Pensiangan", latitude: "4.550000", longitude: "116.316667" }.freeze,
    { state: "Sabah", code: "SBH08", location: "Keningau", latitude: "5.337404", longitude: "116.156680" }.freeze,
    { state: "Sabah", code: "SBH08", location: "Tambunan", latitude: "5.721291", longitude: "116.410779" }.freeze,
    { state: "Sabah", code: "SBH08", location: "Nabawan", latitude: "5.122208", longitude: "116.432583" }.freeze,
    { state: "Sabah", code: "SBH09", location: "Sipitang", latitude: "5.079190", longitude: "115.550825" }.freeze,
    { state: "Sabah", code: "SBH09", location: "Membakut", latitude: "5.527729", longitude: "115.695961" }.freeze,
    { state: "Sabah", code: "SBH09", location: "Beaufort", latitude: "5.345118", longitude: "115.745112" }.freeze,
    { state: "Sabah", code: "SBH09", location: "Kuala Penyu", latitude: "5.571717", longitude: "115.597146" }.freeze,
    { state: "Sabah", code: "SBH09", location: "Weston", latitude: "5.216881", longitude: "115.598801" }.freeze,
    { state: "Sabah", code: "SBH09", location: "Tenom", latitude: "5.130495", longitude: "115.945455" }.freeze,
    { state: "Sabah", code: "SBH09", location: "Long Pa Sia", latitude: "5.978840", longitude: "116.075320" }.freeze,
    { state: "Sabah", code: "SBH01", location: "Sukau", latitude: "5.551318", longitude: "118.302786" }.freeze,
    { state: "Sabah", code: "SBH02", location: "Sandakan Barat", latitude: "5.814070", longitude: "117.732406" }.freeze,
    { state: "Sabah", code: "SBH03", location: "Tawau Timur", latitude: "4.451914", longitude: "118.169232" }.freeze,
    { state: "Sabah", code: "SBH04", location: "Tawau Barat", latitude: "4.487002", longitude: "117.307201" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Putatan", latitude: "5.876932", longitude: "116.058926" }.freeze,
    { state: "Sabah", code: "SBH07", location: "Pantai Barat", latitude: "6.083333", longitude: "116.500000" }.freeze,
    { state: "Sarawak", code: "SWK01", location: "Limbang", latitude: "4.755032", longitude: "115.008146" }.freeze,
    { state: "Sarawak", code: "SWK01", location: "Sundar", latitude: "4.887442", longitude: "115.226701" }.freeze,
    { state: "Sarawak", code: "SWK01", location: "Terusan", latitude: "4.283333", longitude: "115.616666" }.freeze,
    { state: "Sarawak", code: "SWK01", location: "Lawas", latitude: "4.834950", longitude: "115.393738" }.freeze,
    { state: "Sarawak", code: "SWK02", location: "Niah", latitude: "3.866516", longitude: "113.730859" }.freeze,
    { state: "Sarawak", code: "SWK03", location: "Belaga", latitude: "3.200278", longitude: "113.934714" }.freeze,
    { state: "Sarawak", code: "SWK02", location: "Sibuti", latitude: "4.045211", longitude: "113.799896" }.freeze,
    { state: "Sarawak", code: "SWK02", location: "Miri", latitude: "4.399493", longitude: "113.991383" }.freeze,
    { state: "Sarawak", code: "SWK02", location: "Bekenu", latitude: "4.058185", longitude: "113.844193" }.freeze,
    { state: "Sarawak", code: "SWK02", location: "Marudi", latitude: "4.406340", longitude: "114.262830" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Song", latitude: "2.006440", longitude: "112.549760" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Balingian", latitude: "2.930870", longitude: "112.539540" }.freeze,
    { state: "Sarawak", code: "SWK03", location: "Sebauh", latitude: "3.063030", longitude: "113.477610" }.freeze,
    { state: "Sarawak", code: "SWK03", location: "Bintulu", latitude: "3.171322", longitude: "113.041907" }.freeze,
    { state: "Sarawak", code: "SWK03", location: "Tatau", latitude: "2.878960", longitude: "112.855621" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Kapit", latitude: "1.995115", longitude: "112.933085" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Igan", latitude: "2.823991", longitude: "111.710899" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Kanowit", latitude: "2.101223", longitude: "112.153298" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Sibu", latitude: "2.287284", longitude: "111.830535" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Dalat", latitude: "2.666667", longitude: "112.083333" }.freeze,
    { state: "Sarawak", code: "SWK04", location: "Oya", latitude: "2.858436", longitude: "111.875922" }.freeze,
    { state: "Sarawak", code: "SWK05", location: "Belawai", latitude: "2.220691", longitude: "111.218333" }.freeze,
    { state: "Sarawak", code: "SWK05", location: "Matu", latitude: "2.695497", longitude: "111.471668" }.freeze,
    { state: "Sarawak", code: "SWK05", location: "Daro", latitude: "2.527996", longitude: "111.417057" }.freeze,
    { state: "Sarawak", code: "SWK05", location: "Sarikei", latitude: "2.131703", longitude: "111.523728" }.freeze,
    { state: "Sarawak", code: "SWK05", location: "Julau", latitude: "2.024275", longitude: "111.916609" }.freeze,
    { state: "Sarawak", code: "SWK05", location: "Bitangor", latitude: "2.169966", longitude: "111.636641" }.freeze,
    { state: "Sarawak", code: "SWK05", location: "Rajang", latitude: "2.137227", longitude: "111.224885" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Kabong", latitude: "1.803557", longitude: "111.130108" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Lingga", latitude: "1.250000", longitude: "111.166666" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Sri Aman", latitude: "1.237031", longitude: "111.462079" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Engkelili", latitude: "1.138464", longitude: "111.666259" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Betong", latitude: "1.411517", longitude: "111.528999" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Spaoh", latitude: "1.462578", longitude: "111.479364" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Pusa", latitude: "1.619999", longitude: "111.291599" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Saratok", latitude: "1.738795", longitude: "111.337840" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Roban", latitude: "1.866759", longitude: "111.334493" }.freeze,
    { state: "Sarawak", code: "SWK06", location: "Debak", latitude: "1.562670", longitude: "111.422177" }.freeze,
    { state: "Sarawak", code: "SWK07", location: "Samarahan", latitude: "1.442757", longitude: "110.497711" }.freeze,
    { state: "Sarawak", code: "SWK07", location: "Simunjan", latitude: "1.072972", longitude: "110.915332" }.freeze,
    { state: "Sarawak", code: "SWK07", location: "Serian", latitude: "1.167035", longitude: "110.566506" }.freeze,
    { state: "Sarawak", code: "SWK07", location: "Sebuyau", latitude: "1.396803", longitude: "111.071899" }.freeze,
    { state: "Sarawak", code: "SWK07", location: "Meludam", latitude: "1.476546", longitude: "111.213336" }.freeze,
    { state: "Sarawak", code: "SWK08", location: "Kuching", latitude: "1.560000", longitude: "110.345000" }.freeze,
    { state: "Sarawak", code: "SWK08", location: "Bau", latitude: "1.417224", longitude: "110.154629" }.freeze,
    { state: "Sarawak", code: "SWK08", location: "Lundu", latitude: "1.671364", longitude: "109.851969" }.freeze,
    { state: "Sarawak", code: "SWK08", location: "Sematan", latitude: "1.807459", longitude: "109.775842" }.freeze,
    { state: "Sarawak", code: "SWK09", location: "Zon Khas", latitude: "4.962580", longitude: "115.554338" }.freeze,
    { state: "Selangor", code: "SGR01", location: "Gombak", latitude: "3.253502", longitude: "101.653326" }.freeze,
    { state: "Selangor", code: "SGR01", location: "Hulu Selangor", latitude: "3.560105", longitude: "101.658312" }.freeze,
    { state: "Selangor", code: "SGR01", location: "Rawang", latitude: "3.320482", longitude: "101.575924" }.freeze,
    { state: "Selangor", code: "SGR01", location: "Hulu Langat", latitude: "3.113117", longitude: "101.815673" }.freeze,
    { state: "Selangor", code: "SGR01", location: "Sepang", latitude: "2.691369", longitude: "101.750527" }.freeze,
    { state: "Selangor", code: "SGR01", location: "Petaling", latitude: "3.083333", longitude: "101.583333" }.freeze,
    { state: "Selangor", code: "SGR01", location: "Shah Alam", latitude: "3.073281", longitude: "101.518461" }.freeze,
    { state: "Selangor", code: "SGR02", location: "Sabak Bernam", latitude: "3.678777", longitude: "100.990592" }.freeze,
    { state: "Selangor", code: "SGR02", location: "Kuala Selangor", latitude: "3.340184", longitude: "101.249762" }.freeze,
    { state: "Selangor", code: "SGR03", location: "Klang", latitude: "3.044917", longitude: "101.445562" }.freeze,
    { state: "Selangor", code: "SGR03", location: "Kuala Langat", latitude: "2.803828", longitude: "101.495070" }.freeze,
    { state: "Terengganu", code: "TRG01", location: "Kuala Terengganu", latitude: "5.329624", longitude: "103.137014" }.freeze,
    { state: "Terengganu", code: "TRG01", location: "Marang", latitude: "5.207711", longitude: "103.204944" }.freeze,
    { state: "Terengganu", code: "TRG02", location: "Besut", latitude: "5.829012", longitude: "102.552378" }.freeze,
    { state: "Terengganu", code: "TRG02", location: "Setiu", latitude: "5.443798", longitude: "102.825218" }.freeze,
    { state: "Terengganu", code: "TRG03", location: "Hulu Terengganu", latitude: "5.073042", longitude: "103.008937" }.freeze,
    { state: "Terengganu", code: "TRG04", location: "Kemaman", latitude: "4.777790", longitude: "103.033887" }.freeze,
    { state: "Terengganu", code: "TRG04", location: "Dungun", latitude: "4.777790", longitude: "103.033887" }.freeze,
    { state: "Terengganu", code: "TRG01", location: "Kuala Nerus", latitude: "5.333333", longitude: "103.000000" }.freeze,
    { state: "Putrajaya", code: "WLY01", location: "Putrajaya", latitude: "2.926361", longitude: "101.696445" }.freeze,
    { state: "Kuala Lumpur", code: "WLY01", location: "Kuala Lumpur", latitude: "3.139003", longitude: "101.686855" }.freeze,
    { state: "Labuan", code: "WLY02", location: "Labuan", latitude: "5.275346", longitude: "115.247346" }.freeze,
    ].freeze

    def self.data
      DATA
    end
  end
end
