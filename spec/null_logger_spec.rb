
require 'spec_helper'

describe Fluent::Logger::NullLogger do
  context "logger method" do
    let(:logger) { Fluent::Logger::NullLogger.new }

    context "post" do
      it('false') {
        logger.post('tag1', {:foo => :bar}).should == false
        logger.post('tag2', {:foo => :baz}).should == false
      }
    end
  end
end
