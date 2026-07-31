require "spec_helper"
load("spec/fixtures/ruby/delivery.rb")

RSpec.describe Xrechnung::Delivery do
  it "generates xml" do
    expect_xml_eq_fixture(build_delivery, "delivery")
  end
end
