
require 'spec_helper'

describe Fluent::Logger::LoggerBase do
  context "subclass" do
    subject { Class.new(Fluent::Logger::LoggerBase) }
    its(:open) {
      should be_kind_of(Fluent::Logger::LoggerBase)
    }
  end
end
