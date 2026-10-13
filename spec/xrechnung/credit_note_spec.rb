require "spec_helper"

RSpec.describe Xrechnung::Document do
  # A reversing invoice as projo sends it: type code 381, positive amounts, a billing
  # reference to the cancelled invoice.
  let(:document) do
    doc = Xrechnung::Document.new
    doc.id = "RE-2026-0043"
    doc.issue_date = Date.new(2026, 6, 20)
    doc.due_date = Date.new(2026, 7, 20)
    doc.invoice_type_code = invoice_type_code
    doc.buyer_reference = "04011000-12345-34"
    doc.project_reference_id = "P-2026-01"
    doc.billing_reference = Xrechnung::InvoiceDocumentReference.new(id: "RE-2026-0042", issue_date: Date.new(2026, 6, 15))

    doc.accounting_supplier_party = Xrechnung::Party.new(
      postal_address: Xrechnung::PostalAddress.new(
        street_name: "Architektenweg 1", city_name: "Berlin", postal_zone: "10115", country_id: "DE"
      ),
      party_legal_entity: Xrechnung::PartyLegalEntity.new(registration_name: "Musterbüro GmbH"),
      contact: Xrechnung::Contact.new(name: "Anna Architekt", telephone: "+49 30 111111", electronic_mail: "anna@example.de"),
      party_tax_scheme: Xrechnung::PartyTaxScheme.new(tax_scheme_id: "VAT", company_id: "DE123456789")
    )
    doc.accounting_customer_party = Xrechnung::Party.new(
      postal_address: Xrechnung::PostalAddress.new(
        street_name: "Rathausstr. 5", city_name: "Berlin", postal_zone: "10178", country_id: "DE"
      ),
      party_legal_entity: Xrechnung::PartyLegalEntity.new(registration_name: "Bezirksamt Pankow")
    )

    doc.payment_means = Xrechnung::PaymentMeans.new(
      payment_means_code: 58,
      payee_financial_account: Xrechnung::PayeeFinancialAccount.new(id: "DE12500105170648489890")
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
          name: "Stornorechnung zu Rechnung RE-2026-0042",
          commodity_classification: nil,
          classified_tax_category: Xrechnung::TaxCategory.new(id: "S", percent: 19, tax_scheme_id: "VAT")
        ),
        price: Xrechnung::Price.new(price_amount: 1000, base_quantity: Xrechnung::Quantity.new(1, "C62"))
      ),
    ]
    doc
  end

  let(:xml) { document.to_xml }

  context "with credit note type code 381" do
    let(:invoice_type_code) { 381 }

    it "serializes a UBL CreditNote, as BR-CL-01 rejects 381 in a UBL Invoice" do
      expect(xml).to include('<ubl:CreditNote xmlns:ubl="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2"')
      expect(xml).to include("<cbc:CreditNoteTypeCode>381</cbc:CreditNoteTypeCode>")
      expect(xml).not_to include("Invoice-2")
      expect(xml).not_to include("InvoiceTypeCode")
    end

    it "states the plain XRechnung specification (BT-24), as KoSIT has no Extension scenario for a CreditNote" do
      expect(xml).to include("<cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0</cbc:CustomizationID>")
    end

    it "moves the due date (BT-9) into PaymentMeans" do
      expect(xml).not_to include("<cbc:DueDate>")
      expect(xml).to match(%r{<cbc:PaymentMeansCode>58</cbc:PaymentMeansCode>\s*<cbc:PaymentDueDate>2026-07-20</cbc:PaymentDueDate>})
    end

    it "states the project reference (BT-11) as an AdditionalDocumentReference of type 50" do
      expect(xml).not_to include("<cac:ProjectReference>")
      expect(xml).to match(%r{<cac:AdditionalDocumentReference>\s*<cbc:ID>P-2026-01</cbc:ID>\s*<cbc:DocumentTypeCode>50</cbc:DocumentTypeCode>})
    end

    it "places the TaxPointDate before the CreditNoteTypeCode, as the CreditNote schema orders them" do
      document.tax_point_date = Date.new(2026, 6, 18)
      expect(xml).to match(%r{<cbc:IssueDate>2026-06-20</cbc:IssueDate>\s*<cbc:TaxPointDate>2026-06-18</cbc:TaxPointDate>\s*<cbc:CreditNoteTypeCode>})
      expect(xml.scan("<cbc:TaxPointDate>").size).to eq(1)
    end

    it "rejects a due date without payment means, as BT-9 could not be serialized" do
      document.payment_means = nil
      expect { xml }.to raise_error(ArgumentError, /due_date requires payment_means/)
    end

    it "serializes the lines as CreditNoteLine with a CreditedQuantity" do
      expect(xml).to match(%r{<cac:CreditNoteLine>\s*<cbc:ID>1</cbc:ID>\s*<cbc:CreditedQuantity unitCode="C62">1.00</cbc:CreditedQuantity>})
      expect(xml).not_to include("InvoiceLine")
    end
  end

  context "with invoice type code 380" do
    let(:invoice_type_code) { 380 }

    it "keeps serializing a UBL Invoice" do
      expect(xml).to include('<ubl:Invoice xmlns:ubl="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"')
      expect(xml).to include("<cbc:DueDate>2026-07-20</cbc:DueDate>")
      expect(xml).to include("<cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>")
      expect(xml).to include("xrechnung_3.0#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0</cbc:CustomizationID>")
      expect(xml).to match(%r{<cac:ProjectReference>\s*<cbc:ID>P-2026-01</cbc:ID>})
      expect(xml).to match(%r{<cac:InvoiceLine>\s*<cbc:ID>1</cbc:ID>\s*<cbc:InvoicedQuantity unitCode="C62">1.00</cbc:InvoicedQuantity>})
      expect(xml).not_to include("PaymentDueDate")
    end

    it "keeps the TaxPointDate after the notes" do
      document.tax_point_date = Date.new(2026, 6, 18)
      expect(xml).to match(%r{<cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>\s*<cbc:TaxPointDate>2026-06-18</cbc:TaxPointDate>})
    end
  end
end
