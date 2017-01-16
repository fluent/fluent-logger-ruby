
require 'spec_helper'
require 'support/dummy_serverengine'
require 'support/dummy_fluentd'

require 'logger'
require 'stringio'

describe Fluent::Logger::FluentLogger do
  let(:fluentd) {
    DummyFluentd.new
  }

  let(:level_logger) {
    @logger_io = StringIO.new
    logger = ::Logger.new(@logger_io)
    Fluent::Logger::LevelFluentLogger.new('logger-test', {
      :host   => 'localhost',
      :port   => fluentd.port,
      :logger => logger,
      :buffer_overflow_handler => buffer_overflow_handler
    })
  }

  let(:buffer_overflow_handler) { nil }

  let(:logger_io) {
    @logger_io
  }

  context "running fluentd" do

    before(:all) do
      @serverengine = DummyServerengine.new
      @serverengine.startup
    end

    before(:each) do
      fluentd.startup
    end

    after(:each) do
      fluentd.shutdown
    end

    after(:all) do
      @serverengine.shutdown
    end

    context('::Logger compatible methods') do
      it ('initialize default value') {
        level_fluent_logger = Fluent::Logger::LevelFluentLogger.new('logger-test', {
          :host   => 'localhost',
          :port   => fluentd.port,
          :logger => ::Logger.new(StringIO.new),
          :buffer_overflow_handler => buffer_overflow_handler
        })
        expect(level_fluent_logger.level).to eq 0
        expect(level_fluent_logger.progname).to be_nil
        fluentd.wait_transfer # ensure the fluentd accepted the connection
      }

      it ('close') {
        expect(level_logger).to be_connect
        level_logger.close
        expect(level_logger).not_to be_connect
        fluentd.wait_transfer # ensure the fluentd accepted the connection
      }

      it ('reopen') {
        expect(level_logger).to be_connect
        level_logger.reopen
        expect(level_logger).not_to be_connect
        expect(level_logger.info('logger reopen test')).to be true
        fluentd.wait_transfer # ensure the fluentd accepted the connection
      }
    end

    context('add with level') do
      it ('add progname') {
        expect(level_logger.info('some_application'){ 'some application running' }).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.info', {'level' => 'INFO', 'message' => 'some application running', 'progname' => 'some_application' }]
      }

      it ('send log debug') {
        expect(level_logger.debug('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.debug', {'level' => 'DEBUG', 'message' => 'some_application' }]
      }

      it ('send log info') {
        expect(level_logger.info('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.info', {'level' => 'INFO', 'message' => 'some_application' }]
      }

      it ('send log warn') {
        expect(level_logger.warn('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.warn', {'level' => 'WARN', 'message' => 'some_application' }]
      }

      it ('send log error') {
        expect(level_logger.error('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.error', {'level' => 'ERROR', 'message' => 'some_application' }]
      }

      it ('send log fatal') {
        expect(level_logger.fatal('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.fatal', {'level' => 'FATAL', 'message' => 'some_application' }]
      }

      it ('not send log debug') {
        level_logger.level = ::Logger::FATAL

        expect(level_logger.debug('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue).to eq []
      }

      it ('not send log info') {
        level_logger.level = ::Logger::FATAL

        expect(level_logger.info('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue).to eq []
      }

      it ('not send log warn') {
        level_logger.level = ::Logger::FATAL

        expect(level_logger.warn('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue).to eq []
      }

      it ('not send log error') {
        level_logger.level = ::Logger::FATAL

        expect(level_logger.error('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue).to eq []
      }

      it ('define formatter') {
        level_logger.level = ::Logger::DEBUG
        level_logger.formatter = proc do |severity, datetime, progname, message|
          map = { level: severity }
          map[:message] = message if message
          map[:progname] = progname if progname
          map[:stage] = "development"
          map[:service_name] = "some service"
          map
        end

        expect(level_logger.error('some_application')).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq [
          'logger-test.error',
          {'level' => 'ERROR', 'message' => 'some_application', 'stage' => 'development', 'service_name' => 'some service'}
        ]
      }
    end
  end
end
