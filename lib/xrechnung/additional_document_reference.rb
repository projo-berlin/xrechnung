module Xrechnung
  class AdditionalDocumentReference
    include MemberContainer

    # @!attribute id
    #   @return [String]
    member :id, type: String

    # @!attribute issue_date
    #   @return [document_type]
    member :document_type, type: String

    # @!attribute issue_date
    #   @return [base64_blob]
    member :base64_blob, type: Object

    def to_xml(xml)
      xml.cac :AdditionalDocumentReference do
        xml.cbc :ID, id
        xml.cac :Attachment do
          # Written by hand, as Builder escapes text with one regex over all of it, which outlasts
          # Rails' 1s Regexp.timeout for a PDF of about 100 MB. Base64 needs no escaping.
          xml << %(<cbc:EmbeddedDocumentBinaryObject mimeCode="application/pdf" filename=#{id.to_s.encode(xml: :attr)}>)
          xml << base64_blob
          xml << "</cbc:EmbeddedDocumentBinaryObject>\n"
        end
      end
    end
  end
end
