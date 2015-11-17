
require 'spec_helper'

describe Fluent::Logger::LoggerBase do
  context "subclass" do
    let(:subclass) { Class.new(Fluent::Logger::LoggerBase) }
    let(:other_subclass) { Class.new(Fluent::Logger::LoggerBase) }

    describe ".open" do
      subject(:open) { subclass.open }

      it { should be_kind_of(Fluent::Logger::LoggerBase) }

      it "changes Fluent::Logger.default" do
        subclass.open
        expect(Fluent::Logger.default).to be_kind_of(subclass)

        other_subclass.open
        expect(Fluent::Logger.default).to be_kind_of(other_subclass)
      end
    end
  end
end
