require "builder"

module Xrechnung
  module Cii
    # Serializes a populated Xrechnung::Document (the in-memory EN 16931 business
    # object) as ZUGFeRD / Factur-X CII XML (UN/CEFACT Cross Industry Invoice) —
    # the syntax that must be embedded in a ZUGFeRD PDF/A-3.
    #
    # This is the CII counterpart to Xrechnung::Document#to_xml, which emits UBL for
    # XRechnung. Same data, different serialization: we walk the same Document object
    # graph and emit the rsm/ram/udt tree instead of ubl/cac/cbc.
    #
    # Usage:
    #   Xrechnung::Cii::Serializer.new(document).to_xml
    #
    # STATUS: first-cut / spike. Targets the EN16931 (COMFORT) profile. Emits one
    # invoice line (mirroring the projo UBL builder today). `TODO` markers flag BG/BT
    # groups not yet serialized; harden against EN 16931 / ZUGFeRD Schematron next.
    class Serializer
      # EN16931 with the XRechnung 3.0 CIUS. NOTE: this value must match the
      # fx:ConformanceLevel written into the carrying PDF's XMP metadata.
      GUIDELINE_ID = "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0".freeze

      NAMESPACES = {
        "xmlns:rsm" => "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
        "xmlns:qdt" => "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
        "xmlns:ram" => "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
        "xmlns:udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100",
      }.freeze

      # @param document [Xrechnung::Document]
      def initialize(document, guideline_id: GUIDELINE_ID)
        @doc = document
        @guideline_id = guideline_id
      end

      def to_xml(indent: 2, target: "")
        xml = Builder::XmlMarkup.new(indent: indent, target: target)
        xml.instruct! :xml, version: "1.0", encoding: "UTF-8"

        xml.rsm :CrossIndustryInvoice, NAMESPACES do
          exchanged_document_context(xml)
          exchanged_document(xml)
          supply_chain_trade_transaction(xml)
        end

        target
      end

      private

      def exchanged_document_context(xml)
        xml.rsm :ExchangedDocumentContext do
          xml.ram :GuidelineSpecifiedDocumentContextParameter do
            xml.ram :ID, @guideline_id
          end
        end
      end

      # BT-1, BT-3, BT-2, BG-1
      def exchanged_document(xml)
        xml.rsm :ExchangedDocument do
          xml.ram :ID, @doc.id
          xml.ram :TypeCode, @doc.invoice_type_code
          xml.ram :IssueDateTime do
            date_time_string(xml, @doc.issue_date)
          end
          @doc.notes.each do |note|
            next if note.blank?

            xml.ram :IncludedNote do
              xml.ram :Content, note
            end
          end
        end
      end

      def supply_chain_trade_transaction(xml)
        xml.rsm :SupplyChainTradeTransaction do
          @doc.invoice_lines.each { |line| line_item(xml, line) }
          header_trade_agreement(xml)
          header_trade_delivery(xml)
          header_trade_settlement(xml)
        end
      end

      # BG-25 INVOICE LINE
      def line_item(xml, line)
        xml.ram :IncludedSupplyChainTradeLineItem do
          xml.ram :AssociatedDocumentLineDocument do
            xml.ram :LineID, line.id
          end
          xml.ram :SpecifiedTradeProduct do
            xml.ram :Name, line.item&.name
            xml.ram :Description, line.item.description if line.item&.description.present?
          end
          xml.ram :SpecifiedLineTradeAgreement do
            xml.ram :NetPriceProductTradePrice do
              xml.ram :ChargeAmount, line.price&.price_amount&.value_to_s
            end
          end
          xml.ram :SpecifiedLineTradeDelivery do
            xml.ram :BilledQuantity, line.invoiced_quantity.amount_to_s, unitCode: line.invoiced_quantity.unit_code
          end
          xml.ram :SpecifiedLineTradeSettlement do
            line_trade_tax(xml, line.item&.classified_tax_category)
            xml.ram :SpecifiedTradeSettlementLineMonetarySummation do
              xml.ram :LineTotalAmount, line.line_extension_amount.value_to_s
            end
          end
        end
      end

      # BG-4 SELLER / BG-7 BUYER / order + contract references
      def header_trade_agreement(xml)
        xml.ram :ApplicableHeaderTradeAgreement do
          xml.ram :BuyerReference, @doc.buyer_reference if @doc.buyer_reference.present?
          trade_party(xml, :SellerTradeParty, @doc.accounting_supplier_party)
          trade_party(xml, :BuyerTradeParty, @doc.accounting_customer_party)
          if @doc.purchase_order_reference.present?
            xml.ram :BuyerOrderReferencedDocument do
              xml.ram :IssuerAssignedID, @doc.purchase_order_reference
            end
          end
          if @doc.contract_document_reference_id.present?
            xml.ram :ContractReferencedDocument do
              xml.ram :IssuerAssignedID, @doc.contract_document_reference_id
            end
          end
        end
      end

      # BG-13 DELIVERY INFORMATION
      def header_trade_delivery(xml)
        delivery = @doc.delivery
        xml.ram :ApplicableHeaderTradeDelivery do
          # TODO: ShipToTradeParty (BG-15 DELIVER TO) from delivery party + address.
          if delivery&.actual_delivery_date
            xml.ram :ActualDeliverySupplyChainEvent do
              xml.ram :OccurrenceDateTime do
                date_time_string(xml, delivery.actual_delivery_date)
              end
            end
          end
        end
      end

      # BG-16 PAYMENT INSTRUCTIONS / BG-23 VAT BREAKDOWN / BT-20 terms / BG-22 TOTALS
      def header_trade_settlement(xml)
        payment_means = @doc.payment_means
        xml.ram :ApplicableHeaderTradeSettlement do
          xml.ram :PaymentReference, payment_means.payment_id if payment_means&.payment_id.present?
          xml.ram :InvoiceCurrencyCode, @doc.document_currency_code

          settlement_payment_means(xml, payment_means) if payment_means

          @doc.tax_total&.tax_subtotals&.each { |subtotal| applicable_trade_tax(xml, subtotal) }

          if @doc.invoice_start_date.present? && @doc.invoice_end_date.present?
            xml.ram :BillingSpecifiedPeriod do
              xml.ram :StartDateTime do
                date_time_string(xml, @doc.invoice_start_date)
              end
              xml.ram :EndDateTime do
                date_time_string(xml, @doc.invoice_end_date)
              end
            end
          end

          if @doc.payment_terms_note.present? || @doc.due_date
            xml.ram :SpecifiedTradePaymentTerms do
              xml.ram :Description, @doc.payment_terms_note if @doc.payment_terms_note.present?
              if @doc.due_date
                xml.ram :DueDateDateTime do
                  date_time_string(xml, @doc.due_date)
                end
              end
            end
          end

          monetary_summation(xml)
        end
      end

      def settlement_payment_means(xml, payment_means)
        xml.ram :SpecifiedTradeSettlementPaymentMeans do
          xml.ram :TypeCode, payment_means.payment_means_code
          account = payment_means.payee_financial_account
          next unless account

          xml.ram :PayeePartyCreditorFinancialAccount do
            xml.ram :IBANID, account.id
            xml.ram :AccountName, account.name if account.name.present?
          end
          if account.financial_institution_branch_id.present?
            xml.ram :PayeeSpecifiedCreditorFinancialInstitution do
              xml.ram :BICID, account.financial_institution_branch_id
            end
          end
        end
      end

      # BG-23 line in the header VAT breakdown
      def applicable_trade_tax(xml, subtotal)
        category = subtotal.tax_category
        xml.ram :ApplicableTradeTax do
          xml.ram :CalculatedAmount, subtotal.tax_amount.value_to_s
          xml.ram :TypeCode, "VAT"
          xml.ram :BasisAmount, subtotal.taxable_amount.value_to_s
          xml.ram :CategoryCode, category&.id
          xml.ram :RateApplicablePercent, format("%.2f", category.percent) if category
        end
      end

      # BG-22 DOCUMENT TOTALS
      def monetary_summation(xml)
        total = @doc.legal_monetary_total
        return unless total

        tax_total = @doc.tax_total
        xml.ram :SpecifiedTradeSettlementHeaderMonetarySummation do
          xml.ram :LineTotalAmount, total.line_extension_amount&.value_to_s
          xml.ram :TaxBasisTotalAmount, total.tax_exclusive_amount&.value_to_s
          if tax_total
            xml.ram :TaxTotalAmount, tax_total.tax_amount.value_to_s, currencyID: tax_total.tax_amount.currency_id
          end
          xml.ram :GrandTotalAmount, total.tax_inclusive_amount&.value_to_s
          xml.ram :DuePayableAmount, total.payable_amount&.value_to_s
        end
      end

      # ram:SellerTradeParty / ram:BuyerTradeParty (BG-4 / BG-7)
      def trade_party(xml, tag, party)
        return unless party

        xml.ram tag do
          xml.ram :Name, party.party_legal_entity&.registration_name
          if party.party_legal_entity&.company_id.present?
            xml.ram :SpecifiedLegalOrganization do
              xml.ram :ID, party.party_legal_entity.company_id
            end
          end
          defined_trade_contact(xml, party.contact)
          postal_trade_address(xml, party.postal_address)
          if party.endpoint
            xml.ram :URIUniversalCommunication do
              xml.ram :URIID, party.endpoint.id, schemeID: party.endpoint.scheme_id
            end
          end
          if party.party_tax_scheme&.company_id.present?
            xml.ram :SpecifiedTaxRegistration do
              xml.ram :ID, party.party_tax_scheme.company_id, schemeID: "VA"
            end
          end
        end
      end

      def defined_trade_contact(xml, contact)
        return unless contact
        return if contact.name.blank? && contact.telephone.blank? && contact.electronic_mail.blank?

        xml.ram :DefinedTradeContact do
          xml.ram :PersonName, contact.name if contact.name.present?
          if contact.telephone.present?
            xml.ram :TelephoneUniversalCommunication do
              xml.ram :CompleteNumber, contact.telephone
            end
          end
          if contact.electronic_mail.present?
            xml.ram :EmailURIUniversalCommunication do
              xml.ram :URIID, contact.electronic_mail
            end
          end
        end
      end

      def postal_trade_address(xml, address)
        return unless address

        xml.ram :PostalTradeAddress do
          xml.ram :PostcodeCode, address.postal_zone if address.postal_zone.present?
          xml.ram :LineOne, address.street_name if address.street_name.present?
          if address.respond_to?(:additional_street_name) && address.additional_street_name.present?
            xml.ram :LineTwo, address.additional_street_name
          end
          xml.ram :CityName, address.city_name if address.city_name.present?
          xml.ram :CountryID, address.country_id if address.country_id.present?
        end
      end

      # Per-line VAT category (BG-30)
      def line_trade_tax(xml, category)
        return unless category

        xml.ram :ApplicableTradeTax do
          xml.ram :TypeCode, "VAT"
          xml.ram :CategoryCode, category.id
          xml.ram :RateApplicablePercent, format("%.2f", category.percent)
        end
      end

      # udt:DateTimeString format 102 == CCYYMMDD
      def date_time_string(xml, date)
        xml.udt :DateTimeString, date.strftime("%Y%m%d"), format: "102"
      end
    end
  end
end
