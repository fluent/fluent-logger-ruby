
require 'spec_helper'

describe Fluent::Logger::NullLogger do
  context "logger method" do
    let(:logger) { Fluent::Logger::NullLogger.new }

    context "post" do
      it('false') {
        expect(logger.post('tag1', {:foo => :bar})).to be false
        expect(logger.post('tag2', {:foo => :baz})).to be false
      }
    end
  end
end
