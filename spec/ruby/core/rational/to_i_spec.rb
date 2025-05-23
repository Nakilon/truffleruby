require_relative "../../spec_helper"

describe "Rational#to_i" do
  it "converts self to an Integer by truncation" do
    Rational(7, 4).to_i.should eql(1)
    Rational(11, 4).to_i.should eql(2)
  end

  it "converts self to an Integer by truncation" do
    Rational(-7, 4).to_i.should eql(-1)
  end
end
