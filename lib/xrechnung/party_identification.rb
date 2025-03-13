module Xrechnung
  class PartyIdentification
    include MemberContainer

    # @!attribute id
    #   @return [String]
    member :id, type: String

    # noinspection RubyResolve
    def to_xml(xml)
      return "" if id.blank?

      xml.cac :PartyIdentification do
        xml.cbc :ID, id
      end
    end
  end
end
