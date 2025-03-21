module Xrechnung
  class Party
    include MemberContainer

    # @!attribute name
    #   @return [String]
    member :name, type: String


    # @!attribute endpoint
    #   @return [String]
    member :endpoint, type: Xrechnung::Id, optional: true

    # @!attribute postal_address
    #   @return [Xrechnung::PostalAddress]
    member :postal_address, type: Xrechnung::PostalAddress

    # @!attribute party_identification
    #   @return [Xrechnung::PartyIdentification]
    member :party_identification, type: Xrechnung::PartyIdentification

    # @!attribute party_tax_scheme
    #   @return [Xrechnung::PartyTaxScheme]
    member :party_tax_scheme, type: Xrechnung::PartyTaxScheme

    # @!attribute party_legal_entity
    #   @return [Xrechnung::PartyLegalEntity]
    member :party_legal_entity, type: Xrechnung::PartyLegalEntity

    # @!attribute contact
    #   @return [Xrechnung::Contact]
    member :contact, type: Xrechnung::Contact

    attr_accessor :nested

    def initialize(nested: true, **kwargs)
      super(**kwargs)
      self.nested = nested
    end

    # noinspection RubyResolve
    def to_xml(xml)
      if nested
        xml.cac :Party do
          unless endpoint.nil?
            xml.cbc :EndpointID, endpoint.id, schemeID: endpoint.scheme_id
          end
          party_body(xml)
        end
      else
        party_body(xml)
      end
    end

    private

    def party_body(xml)
      unless name.nil? # if blank? -> empty name tag
        xml.cac :PartyName do
          if name == ""
            xml.cbc :Name
          else
            xml.cbc :Name, name
          end
        end
      end

      party_identification&.to_xml(xml)
      postal_address&.to_xml(xml)
      party_tax_scheme&.to_xml(xml) if party_tax_scheme.present?
      party_legal_entity&.to_xml(xml)
      contact&.to_xml(xml)
    end
  end
end
