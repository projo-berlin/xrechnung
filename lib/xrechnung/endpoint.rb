module Xrechnung
  Endpoint = Struct.new(:electronic_address, :scheme) do
    def xml_args
      [electronic_address, schemeID: scheme]
    end
  end
end
