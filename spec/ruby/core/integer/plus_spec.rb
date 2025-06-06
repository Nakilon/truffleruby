require_relative '../../spec_helper'
require_relative 'shared/arithmetic_coerce'

describe "Integer#+" do
  it_behaves_like :integer_arithmetic_coerce_not_rescue, :+

  context "fixnum" do
    it "returns self plus the given Integer" do
      (491 + 2).should == 493
      (90210 + 10).should == 90220

      (9 + bignum_value).should == 18446744073709551625
      (1001 + 5.219).should == 1006.219
    end

    it "raises a TypeError when given a non-Integer" do
      -> {
        (obj = mock('10')).should_receive(:to_int).any_number_of_times.and_return(10)
        13 + obj
      }.should raise_error(TypeError)
      -> { 13 + "10"    }.should raise_error(TypeError)
      -> { 13 + :symbol }.should raise_error(TypeError)
    end
  end

  context "bignum" do
    before :each do
      @bignum = bignum_value(76)
    end

    it "returns self plus the given Integer" do
      (@bignum + 4).should == 18446744073709551696
      (@bignum + 4.2).should be_close(18446744073709551696.2, TOLERANCE)
      (@bignum + bignum_value(3)).should == 36893488147419103311
    end

    it "raises a TypeError when given a non-Integer" do
      -> { @bignum + mock('10') }.should raise_error(TypeError)
      -> { @bignum + "10" }.should raise_error(TypeError)
      -> { @bignum + :symbol}.should raise_error(TypeError)
    end
  end

  it "can be redefined" do
    code = <<~RUBY
      class Integer
        alias_method :old_plus, :+
        def +(other)
          self - other
        end
      end
      result = 1 + 2
      Integer.alias_method :+, :old_plus
      print result
    RUBY
    ruby_exe(code).should == "-1"
  end

  it "coerces the RHS and calls #coerce" do
    obj = mock("integer plus")
    obj.should_receive(:coerce).with(6).and_return([6, 3])
    (6 + obj).should == 9
  end

  it "coerces the RHS and calls #coerce even if it's private" do
    obj = Object.new
    class << obj
      private def coerce(n)
        [n, 3]
      end
    end

    (6 + obj).should == 9
  end
end
