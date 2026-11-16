require "spec_helper"
require "builder"

RSpec.describe Xrechnung::TaxCategory do
  def xml_of(category, **options)
    xml = Builder::XmlMarkup.new
    category.to_xml(xml, **options)
    xml.target!
  end

  it "serializes no exemption reason for a standard-rated category" do
    expect(xml_of(described_class.new(id: "S", percent: 19))).to eq(
      "<cac:TaxCategory><cbc:ID>S</cbc:ID><cbc:Percent>19.00</cbc:Percent>" \
      "<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:TaxCategory>"
    )
  end

  it "serializes the exemption reason code (BT-121) and text (BT-120) between Percent and TaxScheme" do
    category = described_class.new(
      id: "AE", percent: 0, tax_exemption_reason_code: "VATEX-EU-AE", tax_exemption_reason: "Reverse charge"
    )

    expect(xml_of(category)).to eq(
      "<cac:TaxCategory><cbc:ID>AE</cbc:ID><cbc:Percent>0.00</cbc:Percent>" \
      "<cbc:TaxExemptionReasonCode>VATEX-EU-AE</cbc:TaxExemptionReasonCode>" \
      "<cbc:TaxExemptionReason>Reverse charge</cbc:TaxExemptionReason>" \
      "<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:TaxCategory>"
    )
  end
end
