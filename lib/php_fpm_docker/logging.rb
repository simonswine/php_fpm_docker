require 'logger'

module PhpFpmDocker
  # Logging method for all classes
  module Logging
    def logger
      return @logger if @logger
      @logger = ::Logger.new STDOUT
      original_formatter = Logger::Formatter.new
      @logger.formatter = proc { |severity, datetime, progname, msg|
          original_formatter.call(severity, datetime, progname, msg.dump)
      }
      @logger
    end
  end
end
