# coding: utf-8
describe Hallon::Observable do
  let(:klass) do
    Class.new do
      class << self
        def initialize_callbacks
          %w[testing testing_string testing_symbol testing_arguments].map do |m|
            callback_for(m)
          end
        end

        def testing_callback(pointer)
          trigger(pointer, :testing)
        end

        def testing_string_callback(pointer)
          trigger(pointer, "testing_string")
        end

        def testing_symbol_callback(pointer)
          trigger(pointer, :testing_symbol)
        end

        def testing_arguments_callback(pointer, x, y)
          trigger(pointer, :testing_arguments, x * 2, y * 4)
        end
      end

      include Hallon::Observable

      attr_reader :callbacks

      def initialize
        subscribe_for_callbacks do |callbacks|
          @callbacks = callbacks
        end
      end

      def fire!(name, *args, &block)
        ptr = FFI::Pointer.new(pointer)
        cb = self.class.send(:callback_for, name)
        cb.call(ptr, *args)
      end

      def pointer
        FFI::Pointer.new(0xDEADBEEF)
      end

      def session
        Hallon::Session.instance
      end
    end
  end

  describe "ClassMethods" do
    subject { klass }
  end

  subject { klass.new }

  describe "#on" do
    it "should take both a symbol and a string" do
      string = false
      symbol = false

      subject.on("testing_string") { string = true }
      subject.on(:testing_symbol) { symbol = true }

      subject.fire!(:testing_string)
      subject.fire!("testing_symbol")

      string.should be_true
      symbol.should be_true
    end

    it "should receive the callback after it’s been processed" do
      x = nil
      y = nil

      subject.on(:testing_arguments) do |a, b|
        x = a
        y = b
      end

      subject.fire!(:testing_arguments, 10, "Hi")

      x.should eq 20
      y.should eq "HiHiHiHi"
    end

    it "should replace the previous callback if there was one" do
      x = 0

      subject.on(:testing) { x += 1 }
      subject.fire!(:testing)
      x.should eq 1

      subject.on(:testing) { x -= 1 }
      subject.fire!(:testing)
      x.should eq 0
    end

    it "should return the previous callback" do
      previous = proc { puts "hey!" }
      new_one  = proc { puts "ho!" }

      subject.on(:testing, &previous)
      subject.on(:testing, &new_one).should eq previous
      subject.on(:testing, &previous).should eq new_one
    end

    it "should raise an error trying to bind to a non-existing callback" do
      expect { subject.on("nonexisting") {} }.to raise_error(NameError)
    end

    it "should raise an error when not given a block" do
      expect { subject.on(:testing) }.to raise_error(ArgumentError)
    end
  end

  describe "#subscribe_for_callbacks" do
    it "should yield indiscriminetly" do
      expect { subject.send(:subscribe_for_callbacks) }.to raise_error(LocalJumpError)
    end

    it "should do nothing if the result is a null pointer" do
      klass.should_not_receive(:subscribe)
      klass.any_instance.stub(:pointer).and_return(FFI::Pointer::NULL)
      subject.send(:subscribe_for_callbacks) {}
    end

    it "should always yield the *same* object" do
      a = klass.new
      b = klass.new

      a.callbacks.should eq b.callbacks
    end
  end

  describe "#wait_for" do
    around(:each) do |example|
      Timeout.timeout(0.5, SlowTestError, &example)
    end

    it "should not call the given block on notify main thread event" do
      notified = false
      counter  = 0

      session.should_receive(:process_events).twice.and_return do
        if notified
          subject.class.send(:testing_callback, subject.pointer)
        else
          session.class.send(:notify_main_thread_callback, session.pointer)
          notified = true
        end

        0
      end

      subject.wait_for(:testing) do |event|
        event.should eq :testing if (counter += 1) > 1
      end
    end

    it "should time out if waiting for events too long" do
      counter = 0
      session.should_receive(:process_events).once.and_return(0) # and do nothing
      subject.wait_for(:testing) do |event|
        event.should be_nil if (counter += 1) > 1
      end
    end

    it "should call the given block once before waiting" do
      session.should_not_receive(:process_events)
      subject.wait_for { true }
    end
  end

  describe "#protecting_handlers" do
    it "should call the given block, returning the result" do
      was_called = false
      subject.protecting_handlers { was_called = true }.should be_true
      was_called.should be_true
    end

    it "should restore previous handlers on return" do
      subject.on(:testing) { "before" }

      subject.protecting_handlers do
        subject.fire!(:testing).should eq "before"
        subject.on(:testing) { "after" }
        subject.fire!(:testing).should eq "after"
      end

      subject.fire!(:testing).should eq "before"
    end
  end
end
