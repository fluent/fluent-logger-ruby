
require 'spec_helper'

describe Fluent::Logger::TestLogger do
  context "logger method" do
    let(:logger) { Fluent::Logger::TestLogger.new }
    subject { logger.queue }

    context "post" do
      before do
        logger.post('tag1', {:foo => :bar})
        logger.post('tag2', {:foo => :baz})
      end

      its(:first) { should == {:foo => :bar } }
      its(:last)  { should == {:foo => :baz } }
      its("first.tag") { should == "tag1" }
      its("last.tag")  { should == "tag2" }

      it("tag_queue") {
        logger.tag_queue('tag1').size.should == 1
        logger.tag_queue('tag2').size.should == 1
        logger.tag_queue('tag3').size.should == 0
      }
    end

    context "max" do
      before do
        logger.max = 2
        10.times {|i| logger.post(i.to_s, {}) }
      end

      its(:size)      { should == 2 }
      its("last.tag") { should == "9" }
    end
  end
end
