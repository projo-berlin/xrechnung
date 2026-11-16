module Xrechnung
  #     <cbc:ID>S</cbc:ID>
  #     <cbc:Percent>16.00</cbc:Percent>
  #     <cac:TaxScheme>
  #       <cbc:ID>VAT</cbc:ID>
  #     </cac:TaxScheme>
  #
  class TaxCategory
    include MemberContainer

    # • S (Standard rate)
    # • Z (Zero rated goods)
    # • E (Exempt from tax)
    # • AE (VAT Reverse Charge)
    # • K (VAT exempt for EEA intra-community supply of goods and services)
    # • G (Free export item, tax not charged)
    # • O (Services outside scope of tax)
    # • L (Canary Islands general indirect tax)
    # • M (Tax for production, services and importation in Ceuta and Melilla)
    # @!attribute id
    #   @return [String]
    member :id, type: String

    # @!attribute percent
    #   @return [BigDecimal]
    member :percent, type: BigDecimal, transform_value: ->(v) { BigDecimal(v, 0) }

    # @!attribute tax_scheme_id
    #   @return [String]
    member :tax_scheme_id, type: String, default: "VAT"

    # BT-121: why no VAT is charged, as a code from the VATEX list, e.g. "VATEX-EU-AE"
    # for reverse charge. EN 16931 demands BT-120 or BT-121 in the VAT breakdown of every
    # category but S (BR-AE-10, BR-E-10, ...), and allows neither on an invoice line.
    # @!attribute tax_exemption_reason_code
    #   @return [String]
    member :tax_exemption_reason_code, type: String, optional: true

    # BT-120: the same reason as text.
    # @!attribute tax_exemption_reason
    #   @return [String]
    member :tax_exemption_reason, type: String, optional: true

    # noinspection RubyResolve
    def to_xml(xml, root_tag_name: :TaxCategory)
      xml.cac root_tag_name do
        xml.cbc :ID, id
        xml.cbc :Percent, format("%.2f", percent)
        xml.cbc :TaxExemptionReasonCode, tax_exemption_reason_code unless tax_exemption_reason_code.to_s.empty?
        xml.cbc :TaxExemptionReason, tax_exemption_reason unless tax_exemption_reason.to_s.empty?
        xml.cac :TaxScheme do
          xml.cbc :ID, tax_scheme_id
        end
      end
    end
  end
end
