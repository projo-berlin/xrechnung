require "spec_helper"

RSpec.describe Xrechnung::Cii::Serializer do
  # A representative document mirroring what Invoicing::XrechnungenService#build_document
  # produces in the projo app: seller + buyer parties, one line, single VAT rate,
  # payment means, delivery, totals.
  let(:document) do
    doc = Xrechnung::Document.new
    doc.id = "RE-2026-0042"
    doc.issue_date = Date.new(2026, 6, 15)
    doc.due_date = Date.new(2026, 7, 15)
    doc.invoice_type_code = 380
    doc.buyer_reference = "04011000-12345-34"
    doc.notes = ["Vielen Dank fuer Ihren Auftrag."]
    doc.contract_document_reference_id = "V-2025-77"

    doc.accounting_supplier_party = Xrechnung::Party.new(
      endpoint: Xrechnung::Id.new("buero@example.de", "EM"),
      postal_address: Xrechnung::PostalAddress.new(
        street_name: "Architektenweg 1", city_name: "Berlin", postal_zone: "10115", country_id: "DE"
      ),
      party_identification: Xrechnung::PartyIdentification.new(id: "LIEF-1"),
      party_legal_entity: Xrechnung::PartyLegalEntity.new(registration_name: "Musterbüro GmbH", company_id: "HRB 12345"),
      contact: Xrechnung::Contact.new(name: "Anna Architekt", telephone: "+49 30 111111", electronic_mail: "anna@example.de"),
      party_tax_scheme: Xrechnung::PartyTaxScheme.new(tax_scheme_id: "VAT", company_id: "DE123456789")
    )

    doc.accounting_customer_party = Xrechnung::Party.new(
      postal_address: Xrechnung::PostalAddress.new(
        street_name: "Rathausstr. 5", city_name: "Berlin", postal_zone: "10178", country_id: "DE"
      ),
      party_legal_entity: Xrechnung::PartyLegalEntity.new(registration_name: "Bezirksamt Pankow"),
      party_tax_scheme: Xrechnung::PartyTaxScheme.new(tax_scheme_id: "VAT", company_id: "DE987654321")
    )

    doc.delivery = Xrechnung::Delivery.new(actual_delivery_date: Date.new(2026, 5, 31))

    doc.payment_means = Xrechnung::PaymentMeans.new(
      payment_means_code: 58, payment_id: "RE-2026-0042",
      payee_financial_account: Xrechnung::PayeeFinancialAccount.new(
        id: "DE12500105170648489890", name: "Musterbüro GmbH", financial_institution_branch_id: "INGDDEFFXXX"
      )
    )

    doc.tax_total = Xrechnung::TaxTotal.new(
      tax_amount: Xrechnung::Currency::EUR(190),
      tax_subtotals: [
        Xrechnung::TaxSubtotal.new(
          taxable_amount: Xrechnung::Currency::EUR(1000),
          tax_amount: Xrechnung::Currency::EUR(190),
          tax_category: Xrechnung::TaxCategory.new(id: "S", percent: 19, tax_scheme_id: "VAT")
        ),
      ]
    )

    doc.legal_monetary_total = Xrechnung::LegalMonetaryTotal.new(
      line_extension_amount: 1000, tax_exclusive_amount: 1000, tax_inclusive_amount: 1190, payable_amount: 1190
    )

    doc.invoice_lines = [
      Xrechnung::InvoiceLine.new(
        id: 1,
        invoiced_quantity: Xrechnung::Quantity.new(1, "C62"),
        line_extension_amount: 1000,
        item: Xrechnung::Item.new(
          description: "Architektenleistung Leistungsphase 5",
          name: "Planungsleistung",
          commodity_classification: nil,
          classified_tax_category: Xrechnung::TaxCategory.new(id: "S", percent: 19, tax_scheme_id: "VAT")
        ),
        price: Xrechnung::Price.new(price_amount: 1000, base_quantity: Xrechnung::Quantity.new(1, "C62"))
      ),
    ]

    doc
  end

  subject(:xml) { described_class.new(document).to_xml }

  it "produces a complete, balanced XML document" do
    # Builder guarantees well-formedness by construction; full XML-schema /
    # Schematron validation is done downstream via the Mustang CLI. Here we just
    # assert the declaration and a balanced root element.
    expect(xml).to start_with("<?xml")
    expect(xml).to match(%r{<rsm:CrossIndustryInvoice\b.*</rsm:CrossIndustryInvoice>\s*\z}m)
  end

  it "is a CrossIndustryInvoice with the ZUGFeRD namespaces" do
    expect(xml).to include("<rsm:CrossIndustryInvoice")
    expect(xml).to include('xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"')
    expect(xml).to include('xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"')
  end

  it "declares the EN16931 guideline profile" do
    expect(xml).to include("<ram:ID>#{described_class::GUIDELINE_ID}</ram:ID>")
  end

  it "declares the business process (BT-23) from the document profile_id" do
    expect(xml).to include("<ram:BusinessProcessSpecifiedDocumentContextParameter>")
    expect(xml).to include("<ram:ID>#{document.profile_id}</ram:ID>")
  end

  it "serializes the document header (BT-1, BT-3, BT-2)" do
    expect(xml).to include("<ram:ID>RE-2026-0042</ram:ID>")
    expect(xml).to include("<ram:TypeCode>380</ram:TypeCode>")
    expect(xml).to include('<udt:DateTimeString format="102">20260615</udt:DateTimeString>')
  end

  it "maps seller and buyer to TradeParty nodes" do
    expect(xml).to include("<ram:SellerTradeParty>")
    expect(xml).to include("<ram:Name>Musterbüro GmbH</ram:Name>")
    expect(xml).to include("<ram:BuyerTradeParty>")
    expect(xml).to include("<ram:Name>Bezirksamt Pankow</ram:Name>")
  end

  it "maps VAT and totals into the settlement group" do
    expect(xml).to include("<ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>")
    expect(xml).to include('<ram:TaxTotalAmount currencyID="EUR">190.00</ram:TaxTotalAmount>')
    expect(xml).to include("<ram:GrandTotalAmount>1190.00</ram:GrandTotalAmount>")
    expect(xml).to include("<ram:DuePayableAmount>1190.00</ram:DuePayableAmount>")
  end

  it "omits TotalPrepaidAmount when the document has no prepaid amount" do
    expect(xml).not_to include("<ram:TotalPrepaidAmount>")
  end

  context "with a prepaid amount (BT-113)" do
    before do
      document.legal_monetary_total = Xrechnung::LegalMonetaryTotal.new(
        line_extension_amount: 1000, tax_exclusive_amount: 1000, tax_inclusive_amount: 1190,
        prepaid_amount: 59.5, payable_amount: 1130.5
      )
    end

    it "serializes it between GrandTotalAmount and DuePayableAmount" do
      expect(xml).to match(
        %r{<ram:GrandTotalAmount>1190\.00</ram:GrandTotalAmount>\s*<ram:TotalPrepaidAmount>59\.50</ram:TotalPrepaidAmount>\s*<ram:DuePayableAmount>1130\.50</ram:DuePayableAmount>}
      )
    end
  end

  it "maps the IBAN/BIC payment means" do
    expect(xml).to include("<ram:IBANID>DE12500105170648489890</ram:IBANID>")
    expect(xml).to include("<ram:BICID>INGDDEFFXXX</ram:BICID>")
  end

  context "with supporting documents (BG-24)" do
    subject(:xml) do
      described_class.new(
        document,
        attachments: [{ filename: "anhang-1.pdf", name: "Leistungsnachweis", mime: "application/pdf", content: "%PDF-1.4 stub" }]
      ).to_xml
    end

    it "declares each attachment as an AdditionalReferencedDocument with its base64 binary" do
      expect(xml).to include("<ram:AdditionalReferencedDocument>")
      expect(xml).to include("<ram:IssuerAssignedID>anhang-1.pdf</ram:IssuerAssignedID>")
      expect(xml).to include("<ram:TypeCode>916</ram:TypeCode>")
      expect(xml).to include("<ram:Name>Leistungsnachweis</ram:Name>")
      expect(xml).to include(%(<ram:AttachmentBinaryObject mimeCode="application/pdf" filename="anhang-1.pdf">))
      expect(xml).to include(Base64.strict_encode64("%PDF-1.4 stub"))
    end
  end
end
