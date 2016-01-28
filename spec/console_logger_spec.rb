
require 'spec_helper'
require 'stringio'
require 'tempfile'
require 'pathname'

describe Fluent::Logger::ConsoleLogger do
  before(:each) {
    Timecop.freeze Time.local(2008, 9, 1, 10, 5, 0)
  }
  after(:each) {
    Timecop.return
  }

  context "IO output" do
    let(:io) { StringIO.new }
    let(:logger) { Fluent::Logger::ConsoleLogger.new(io) }

    subject {
      io
    }

    context "post and read" do
      before do
        logger.post('example', {:foo => :bar})
        io.rewind
      end
      its(:read)  { should eq %Q!Sep  1 10:05:00 example: foo="bar"\n! }
    end
  end

  context "Filename output" do
    let(:path) {
      @tmp = Tempfile.new('fluent-logger') # ref instance var because Tempfile.close(true) check GC
      filename = @tmp.path
      @tmp.close(true)
      Pathname.new(filename)
    }
    let(:logger) { Fluent::Logger::ConsoleLogger.new(path.to_s) }

    subject { path }
    after { path.unlink }

    context "post and read" do
      before do
        logger.post('example', {:foo => :bar})
        logger.close
      end
      its(:read)  { should eq %Q!Sep  1 10:05:00 example: foo="bar"\n! }
    end

    context "reopen" do
      before do
        logger.post('example', {:foo => :baz})
        logger.close
        logger.reopen!
      end
      its(:read)  { should eq %Q!Sep  1 10:05:00 example: foo="baz"\n! }
    end
  end

  context "Invalid output" do
    it {
      expect {
        Fluent::Logger::ConsoleLogger.new(nil)
      }.to raise_error(RuntimeError)
    }
  end
end
