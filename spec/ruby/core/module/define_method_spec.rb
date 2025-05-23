require_relative '../../spec_helper'
require_relative 'fixtures/classes'

class DefineMethodSpecClass
end

describe "passed { |a, b = 1|  } creates a method that" do
  before :each do
    @klass = Class.new do
      define_method(:m) { |a, b = 1| return a, b }
    end
  end

  it "raises an ArgumentError when passed zero arguments" do
    -> { @klass.new.m }.should raise_error(ArgumentError)
  end

  it "has a default value for b when passed one argument" do
    @klass.new.m(1).should == [1, 1]
  end

  it "overrides the default argument when passed two arguments" do
    @klass.new.m(1, 2).should == [1, 2]
  end

  it "raises an ArgumentError when passed three arguments" do
    -> { @klass.new.m(1, 2, 3) }.should raise_error(ArgumentError)
  end
end

describe "Module#define_method when given an UnboundMethod" do
  it "passes the given arguments to the new method" do
    klass = Class.new do
      def test_method(arg1, arg2)
        [arg1, arg2]
      end
      define_method(:another_test_method, instance_method(:test_method))
    end

    klass.new.another_test_method(1, 2).should == [1, 2]
  end

  it "adds the new method to the methods list" do
    klass = Class.new do
      def test_method(arg1, arg2)
        [arg1, arg2]
      end
      define_method(:another_test_method, instance_method(:test_method))
    end
    klass.new.should have_method(:another_test_method)
  end

  describe "defining a method on a singleton class" do
    before do
      klass = Class.new
      class << klass
        def test_method
          :foo
        end
      end
      child = Class.new(klass)
      sc = class << child; self; end
      sc.send :define_method, :another_test_method, klass.method(:test_method).unbind

      @class = child
    end

    it "doesn't raise TypeError when calling the method" do
      @class.another_test_method.should == :foo
    end
  end

  it "sets the new method's visibility to the current frame's visibility" do
    foo = Class.new do
      def ziggy
        'piggy'
      end
      private :ziggy

      # make sure frame visibility is public
      public

      define_method :piggy, instance_method(:ziggy)
    end

    -> { foo.new.ziggy }.should raise_error(NoMethodError)
    foo.new.piggy.should == 'piggy'
  end
end

describe "Module#define_method" do
  describe "when the default definee is not the same as the module" do
    it "sets the visibility of the method to public" do
      klass = Class.new
      class << klass
        private
        define_method(:meta) do
          define_method(:foo) { :foo }
        end
      end

      klass.send :meta
      klass.new.foo.should == :foo
    end
  end
end

describe "Module#define_method when name is not a special private name" do
  describe "given an UnboundMethod" do
    describe "and called from the target module" do
      it "sets the visibility of the method to the current visibility" do
        klass = Class.new do
          define_method(:bar, ModuleSpecs::EmptyFooMethod)
          private
          define_method(:baz, ModuleSpecs::EmptyFooMethod)
        end

        klass.should have_public_instance_method(:bar)
        klass.should have_private_instance_method(:baz)
      end
    end

    describe "and called from another module" do
      it "sets the visibility of the method to public" do
        klass = Class.new
        Class.new do
          klass.send(:define_method, :bar, ModuleSpecs::EmptyFooMethod)
          private
          klass.send(:define_method, :baz, ModuleSpecs::EmptyFooMethod)
        end

        klass.should have_public_instance_method(:bar)
        klass.should have_public_instance_method(:baz)
      end
    end

    it "sets the method owner for a dynamically added method with a different original owner" do
      mixin_module = Module.new do
        def bar; end
      end

      foo = Object.new
      foo.singleton_class.define_method(:bar, mixin_module.instance_method(:bar))

      foo.method(:bar).owner.should == foo.singleton_class
    end
  end

  describe "passed a block" do
    describe "and called from the target module" do
      it "sets the visibility of the method to the current visibility" do
        klass = Class.new do
          define_method(:bar) {}
          private
          define_method(:baz) {}
        end

        klass.should have_public_instance_method(:bar)
        klass.should have_private_instance_method(:baz)
      end
    end

    describe "and called from another module" do
      it "sets the visibility of the method to public" do
        klass = Class.new
        Class.new do
          klass.send(:define_method, :bar) {}
          private
          klass.send(:define_method, :baz) {}
        end

        klass.should have_public_instance_method(:bar)
        klass.should have_public_instance_method(:baz)
      end
    end
  end
end

describe "Module#define_method when name is :initialize" do
  describe "passed a block" do
    it "sets visibility to private when method name is :initialize" do
      klass = Class.new do
        define_method(:initialize) { }
      end
      klass.should have_private_instance_method(:initialize)
    end
  end

  describe "given an UnboundMethod" do
    it "sets the visibility to private when method is named :initialize" do
      klass = Class.new do
        def test_method
        end
        define_method(:initialize, instance_method(:test_method))
      end
      klass.should have_private_instance_method(:initialize)
    end
  end
end

describe "Module#define_method" do
  it "defines the given method as an instance method with the given name in self" do
    class DefineMethodSpecClass
      def test1
        "test"
      end
      define_method(:another_test, instance_method(:test1))
    end

    o = DefineMethodSpecClass.new
    o.test1.should == o.another_test
  end

  it "calls #method_added after the method is added to the Module" do
    DefineMethodSpecClass.should_receive(:method_added).with(:test_ma)

    class DefineMethodSpecClass
      define_method(:test_ma) { true }
    end
  end

  it "defines a new method with the given name and the given block as body in self" do
    class DefineMethodSpecClass
      define_method(:block_test1) { self }
      define_method(:block_test2, &-> { self })
    end

    o = DefineMethodSpecClass.new
    o.block_test1.should == o
    o.block_test2.should == o
  end

  it "raises TypeError if name cannot converted to String" do
    -> {
      Class.new { define_method(1001, -> {}) }
    }.should raise_error(TypeError, /is not a symbol nor a string/)

    -> {
      Class.new { define_method([], -> {}) }
    }.should raise_error(TypeError, /is not a symbol nor a string/)
  end

  it "converts non-String name to String with #to_str" do
    obj = Object.new
    def obj.to_str() "foo" end

    new_class = Class.new { define_method(obj, -> { :called }) }
    new_class.new.foo.should == :called
  end

  it "raises TypeError when #to_str called on non-String name returns non-String value" do
    obj = Object.new
    def obj.to_str() [] end

    -> {
      Class.new { define_method(obj, -> {}) }
    }.should raise_error(TypeError, /can't convert Object to String/)
  end

  it "raises a TypeError when the given method is no Method/Proc" do
    -> {
      Class.new { define_method(:test, "self") }
    }.should raise_error(TypeError, "wrong argument type String (expected Proc/Method/UnboundMethod)")

    -> {
      Class.new { define_method(:test, 1234) }
    }.should raise_error(TypeError, "wrong argument type Integer (expected Proc/Method/UnboundMethod)")

    -> {
      Class.new { define_method(:test, nil) }
    }.should raise_error(TypeError, "wrong argument type NilClass (expected Proc/Method/UnboundMethod)")
  end

  it "uses provided Method/Proc even if block is specified" do
    new_class = Class.new do
      define_method(:test, -> { :method_is_called }) do
        :block_is_called
      end
    end

    new_class.new.test.should == :method_is_called
  end

  it "raises an ArgumentError when no block is given" do
    -> {
      Class.new { define_method(:test) }
    }.should raise_error(ArgumentError)
  end

  it "does not use the caller block when no block is given" do
    o = Object.new
    def o.define(name)
      self.class.class_eval do
        define_method(name)
      end
    end

    -> {
      o.define(:foo) { raise "not used" }
    }.should raise_error(ArgumentError)
  end

  it "does not change the arity check style of the original proc" do
    class DefineMethodSpecClass
      prc = Proc.new { || true }
      define_method("proc_style_test", &prc)
    end

    obj = DefineMethodSpecClass.new
    -> { obj.proc_style_test :arg }.should raise_error(ArgumentError)
  end

  it "raises a FrozenError if frozen" do
    -> {
      Class.new { freeze; define_method(:foo) {} }
    }.should raise_error(FrozenError)
  end

  it "accepts a Method (still bound)" do
    class DefineMethodSpecClass
      attr_accessor :data
      def inspect_data
        "data is #{@data}"
      end
    end
    o = DefineMethodSpecClass.new
    o.data = :foo
    m = o.method(:inspect_data)
    m.should be_an_instance_of(Method)
    klass = Class.new(DefineMethodSpecClass)
    klass.send(:define_method,:other_inspect, m)
    c = klass.new
    c.data = :bar
    c.other_inspect.should == "data is bar"
    ->{o.other_inspect}.should raise_error(NoMethodError)
  end

  it "raises a TypeError when a Method from a singleton class is defined on another class" do
    c = Class.new do
      class << self
        def foo
        end
      end
    end
    m = c.method(:foo)

    -> {
      Class.new { define_method :bar, m }
    }.should raise_error(TypeError, /can't bind singleton method to a different class/)
  end

  it "raises a TypeError when a Method from one class is defined on an unrelated class" do
    c = Class.new do
      def foo
      end
    end
    m = c.new.method(:foo)

    -> {
      Class.new { define_method :bar, m }
    }.should raise_error(TypeError)
  end

  it "accepts an UnboundMethod from an attr_accessor method" do
    class DefineMethodSpecClass
      attr_accessor :accessor_method
    end

    m = DefineMethodSpecClass.instance_method(:accessor_method)
    o = DefineMethodSpecClass.new

    DefineMethodSpecClass.send(:undef_method, :accessor_method)
    -> { o.accessor_method }.should raise_error(NoMethodError)

    DefineMethodSpecClass.send(:define_method, :accessor_method, m)

    o.accessor_method = :abc
    o.accessor_method.should == :abc
  end

  it "accepts a proc from a method" do
    class ProcFromMethod
      attr_accessor :data
      def cool_method
        "data is #{@data}"
      end
    end

    object1 = ProcFromMethod.new
    object1.data = :foo

    method_proc = object1.method(:cool_method).to_proc
    klass = Class.new(ProcFromMethod)
    klass.send(:define_method, :other_cool_method, &method_proc)

    object2 = klass.new
    object2.data = :bar
    object2.other_cool_method.should == "data is foo"
  end

  it "accepts a proc from a Symbol" do
    symbol_proc = :+.to_proc
    klass = Class.new do
      define_method :foo, &symbol_proc
    end
    klass.new.foo(1, 2).should == 3
  end

  it "maintains the Proc's scope" do
    class DefineMethodByProcClass
      in_scope = true
      method_proc = proc { in_scope }

      define_method(:proc_test, &method_proc)
    end

    o = DefineMethodByProcClass.new
    o.proc_test.should be_true
  end

  it "accepts a String method name" do
    klass = Class.new do
      define_method("string_test") do
        "string_test result"
      end
    end

    klass.new.string_test.should == "string_test result"
  end

  it "is a public method" do
    Module.should have_public_instance_method(:define_method)
  end

  it "returns its symbol" do
    class DefineMethodSpecClass
      method = define_method("return_test") { true }
      method.should == :return_test
    end
  end

  it "allows an UnboundMethod from a module to be defined on a class" do
    klass = Class.new {
      define_method :bar, ModuleSpecs::UnboundMethodTest.instance_method(:foo)
    }
    klass.new.should respond_to(:bar)
  end

  it "allows an UnboundMethod from a parent class to be defined on a child class" do
    parent = Class.new { define_method(:foo) { :bar } }
    child = Class.new(parent) {
      define_method :baz, parent.instance_method(:foo)
    }
    child.new.should respond_to(:baz)
  end

  it "allows an UnboundMethod from a module to be defined on another unrelated module" do
    mod = Module.new {
      define_method :bar, ModuleSpecs::UnboundMethodTest.instance_method(:foo)
    }
    klass = Class.new { include mod }
    klass.new.should respond_to(:bar)
  end


  it "allows an UnboundMethod of a Kernel method retrieved from Object to defined on a BasicObject subclass" do
    klass = Class.new(BasicObject) do
      define_method :instance_of?, ::Object.instance_method(:instance_of?)
    end
    klass.new.instance_of?(klass).should == true
  end

  it "raises a TypeError when an UnboundMethod from a child class is defined on a parent class" do
    -> {
      ParentClass = Class.new { define_method(:foo) { :bar } }
      ChildClass = Class.new(ParentClass) { define_method(:foo) { :baz } }
      ParentClass.send :define_method, :foo, ChildClass.instance_method(:foo)
    }.should raise_error(TypeError, /bind argument must be a subclass of ChildClass/)
  ensure
    Object.send(:remove_const, :ParentClass)
    Object.send(:remove_const, :ChildClass)
  end

  it "raises a TypeError when an UnboundMethod from one class is defined on an unrelated class" do
    -> {
      DestinationClass = Class.new {
        define_method :bar, ModuleSpecs::InstanceMeth.instance_method(:foo)
      }
    }.should raise_error(TypeError, /bind argument must be a subclass of ModuleSpecs::InstanceMeth/)
  end

  it "raises a TypeError when an UnboundMethod from a singleton class is defined on another class" do
    c = Class.new do
      class << self
        def foo
        end
      end
    end
    m = c.method(:foo).unbind

    -> {
      Class.new { define_method :bar, m }
    }.should raise_error(TypeError, /can't bind singleton method to a different class/)
  end

  it "defines a new method with public visibility when a Method passed and the class/module of the context isn't equal to the receiver of #define_method" do
    c = Class.new do
      private def foo
        "public"
      end
    end

    object = c.new
    object.singleton_class.define_method(:bar, object.method(:foo))

    object.bar.should == "public"
  end

  it "defines the new method according to the scope visibility when a Method passed and the class/module of the context is equal to the receiver of #define_method" do
    c = Class.new do
      def foo; end
    end

    object = c.new
    object.singleton_class.class_eval do
      private
      define_method(:bar, c.new.method(:foo))
    end

    -> { object.bar }.should raise_error(NoMethodError)
  end
end

describe "Module#define_method" do
  describe "passed {  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { :called }
      end
    end

    it "returns the value computed by the block when passed zero arguments" do
      @klass.new.m().should == :called
    end

    it "raises an ArgumentError when passed one argument" do
      -> { @klass.new.m 1 }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed two arguments" do
      -> { @klass.new.m 1, 2 }.should raise_error(ArgumentError)
    end
  end

  describe "passed { ||  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { || :called }
      end
    end

    it "returns the value computed by the block when passed zero arguments" do
      @klass.new.m().should == :called
    end

    it "raises an ArgumentError when passed one argument" do
      -> { @klass.new.m 1 }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed two arguments" do
      -> { @klass.new.m 1, 2 }.should raise_error(ArgumentError)
    end
  end

  describe "passed { |a|  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { |a| a }
      end
    end

    it "raises an ArgumentError when passed zero arguments" do
      -> { @klass.new.m }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed zero arguments and a block" do
      -> { @klass.new.m { :computed } }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed two arguments" do
      -> { @klass.new.m 1, 2 }.should raise_error(ArgumentError)
    end

    it "receives the value passed as the argument when passed one argument" do
      @klass.new.m(1).should == 1
    end
  end

  describe "passed { |a,|  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { |a,| a }
      end
    end

    it "raises an ArgumentError when passed zero arguments" do
      -> { @klass.new.m }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed zero arguments and a block" do
      -> { @klass.new.m { :computed } }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed two arguments" do
      -> { @klass.new.m 1, 2 }.should raise_error(ArgumentError)
    end

    it "receives the value passed as the argument when passed one argument" do
      @klass.new.m(1).should == 1
    end

    it "does not destructure the passed argument" do
      @klass.new.m([1, 2]).should == [1, 2]
      # for comparison:
      proc { |a,| a }.call([1, 2]).should == 1
    end
  end

  describe "passed { |*a|  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { |*a| a }
      end
    end

    it "receives an empty array as the argument when passed zero arguments" do
      @klass.new.m().should == []
    end

    it "receives the value in an array when passed one argument" do
      @klass.new.m(1).should == [1]
    end

    it "receives the values in an array when passed two arguments" do
      @klass.new.m(1, 2).should == [1, 2]
    end
  end

  describe "passed { |a, *b|  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { |a, *b| return a, b }
      end
    end

    it "raises an ArgumentError when passed zero arguments" do
      -> { @klass.new.m }.should raise_error(ArgumentError)
    end

    it "returns the value computed by the block when passed one argument" do
      @klass.new.m(1).should == [1, []]
    end

    it "returns the value computed by the block when passed two arguments" do
      @klass.new.m(1, 2).should == [1, [2]]
    end

    it "returns the value computed by the block when passed three arguments" do
      @klass.new.m(1, 2, 3).should == [1, [2, 3]]
    end
  end

  describe "passed { |a, b|  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { |a, b| return a, b }
      end
    end

    it "returns the value computed by the block when passed two arguments" do
      @klass.new.m(1, 2).should == [1, 2]
    end

    it "raises an ArgumentError when passed zero arguments" do
      -> { @klass.new.m }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed one argument" do
      -> { @klass.new.m 1 }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed one argument and a block" do
      -> { @klass.new.m(1) { } }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed three arguments" do
      -> { @klass.new.m 1, 2, 3 }.should raise_error(ArgumentError)
    end
  end

  describe "passed { |a, b, *c|  } creates a method that" do
    before :each do
      @klass = Class.new do
        define_method(:m) { |a, b, *c| return a, b, c }
      end
    end

    it "raises an ArgumentError when passed zero arguments" do
      -> { @klass.new.m }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed one argument" do
      -> { @klass.new.m 1 }.should raise_error(ArgumentError)
    end

    it "raises an ArgumentError when passed one argument and a block" do
      -> { @klass.new.m(1) { } }.should raise_error(ArgumentError)
    end

    it "receives an empty array as the third argument when passed two arguments" do
      @klass.new.m(1, 2).should == [1, 2, []]
    end

    it "receives the third argument in an array when passed three arguments" do
      @klass.new.m(1, 2, 3).should == [1, 2, [3]]
    end
  end
end

describe "Module#define_method when passed a Method object" do
  before :each do
    @klass = Class.new do
      def m(a, b, *c)
        :m
      end
    end

    @obj = @klass.new
    m = @obj.method :m

    @klass.class_exec do
      define_method :n, m
    end
  end

  it "defines a method with the same #arity as the original" do
    @obj.method(:n).arity.should == @obj.method(:m).arity
  end

  it "defines a method with the same #parameters as the original" do
    @obj.method(:n).parameters.should == @obj.method(:m).parameters
  end
end

describe "Module#define_method when passed an UnboundMethod object" do
  before :each do
    @klass = Class.new do
      def m(a, b, *c)
        :m
      end
    end

    @obj = @klass.new
    m = @klass.instance_method :m

    @klass.class_exec do
      define_method :n, m
    end
  end

  it "defines a method with the same #arity as the original" do
    @obj.method(:n).arity.should == @obj.method(:m).arity
  end

  it "defines a method with the same #parameters as the original" do
    @obj.method(:n).parameters.should == @obj.method(:m).parameters
  end
end

describe "Module#define_method when passed a Proc object" do
  describe "and a method is defined inside" do
    it "defines the nested method in the default definee where the Proc was created" do
      prc = nil
      t = Class.new do
        prc = -> {
          def nested_method_in_proc_for_define_method
            42
          end
        }
      end

      c = Class.new do
        define_method(:test, prc)
      end

      o = c.new
      o.test
      o.should_not have_method :nested_method_in_proc_for_define_method

      t.new.nested_method_in_proc_for_define_method.should == 42
    end
  end
end

describe "Module#define_method when passed a block" do
  describe "behaves exactly like a lambda" do
    it "for return" do
      Class.new do
        define_method(:foo) do
          return 42
        end
      end.new.foo.should == 42
    end

    it "for break" do
      Class.new do
        define_method(:foo) do
          break 42
        end
      end.new.foo.should == 42
    end

    it "for next" do
      Class.new do
        define_method(:foo) do
          next 42
        end
      end.new.foo.should == 42
    end

    it "for redo" do
      Class.new do
        result = []
        define_method(:foo) do
          if result.empty?
            result << :first
            redo
          else
            result << :second
            result
          end
        end
      end.new.foo.should == [:first, :second]
    end
  end
end
