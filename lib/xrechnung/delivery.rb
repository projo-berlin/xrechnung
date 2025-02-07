module Xrechnung
  class Delivery
    include MemberContainer
    #
    # @!attribute actual_delivery_date
    #   @return [String]
    member :actual_delivery_date, type: Date

    # @!attribute party_name
    #   @return [String]
    member :party_name, type: String

    # @!attribute street_name
    #   @return [String]
    member :street_name, type: String

    # @!attribute city_name
    #   @return [String]
    member :city_name, type: String

    # @!attribute postal_zone
    #   @return [String]
    member :postal_zone, type: String

    # @!attribute country_id
    #   @return [String]
    member :country_id, type: String

    # noinspection RubyResolve
    def to_xml(xml)
      xml.cac :Delivery do
        xml.cbc :ActualDeliveryDate, actual_delivery_date unless actual_delivery_date.nil?
        if city_name.present? || postal_zone.present?
          xml.cac :DeliveryLocation do
            xml.cac :Address do
              xml.cbc :StreetName, street_name unless street_name.nil?
              xml.cbc :CityName, city_name unless city_name.nil?
              xml.cbc :PostalZone, postal_zone unless postal_zone.nil?
              xml.cac :Country do
                xml.cbc :IdentificationCode, country_id
              end
            end
          end
        end
        if party_name.present?
          xml.cac :DeliveryParty do
            xml.cac :PartyName do
              xml.cbc :Name, party_name
            end
          end
        end
      end
    end
  end
end
