require "spec_helper"
require "base64"

RSpec.describe Xrechnung::AdditionalDocumentReference do
  def to_xml(reference)
    xml = Builder::XmlMarkup.new(indent: 2)
    reference.to_xml(xml)
    xml.target!
  end

  it "embeds the PDF as base64 that decodes to the original bytes" do
    pdf = "%PDF-1.4 <äöü & more>".b
    xml = to_xml(described_class.new(id: "Rechnung 1 & 2.pdf", base64_blob: Base64.strict_encode64(pdf)))

    blob = xml[%r{<cbc:EmbeddedDocumentBinaryObject [^>]*>(.*?)</cbc:EmbeddedDocumentBinaryObject>}m, 1]
    expect(Base64.decode64(blob)).to eq(pdf)
    expect(xml).to include('filename="Rechnung 1 &amp; 2.pdf"')
  end

  # Rails sets Regexp.timeout to 1s. Builder's escaping runs one regex over the whole text,
  # so a PDF of about 100 MB timed out in production.
  it "embeds a large PDF without running the regex escaping over it" do
    blob = Base64.strict_encode64(Random.bytes(5 * 1024 * 1024))
    previous_timeout = Regexp.timeout
    Regexp.timeout = 0.001

    expect { to_xml(described_class.new(id: "large.pdf", base64_blob: blob)) }.not_to raise_error
  ensure
    Regexp.timeout = previous_timeout
  end
end
