module Xrechnung
  class PartyTaxScheme
    include MemberContainer

    # @!attribute company_id
    #   @return [String]
    member :company_id, type: String

    # @!attribute tax_scheme_id
    #   @return [String]
    member :tax_scheme_id, type: String, default: "VAT"

    # noinspection RubyResolve
    def to_xml(xml)
      return "" if company_id.blank? || tax_scheme_id.blank?

      xml.cac :PartyTaxScheme do
        xml.cbc :CompanyID, company_id
        xml.cac :TaxScheme do
          xml.cbc :ID, tax_scheme_id
        end
      end
    end
  end
end
