def build_delivery
  Xrechnung::Delivery.new(
    street_name: "Beispielgasse 17",
    city_name:   "Baustadt",
    postal_zone: "12345",
    country_id:  "DE",
  )
end
