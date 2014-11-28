require 'logger'
require 'php_fpm_docker'

module PhpFpmDocker
  # Logging method for all classes
  module Logging
    def logger
      return @logger if @logger
      @logger = ::Logger.new PhpFpmDocker::LOG_FILE
      @logger.formatter = proc { |severity, datetime, _progname, msg|
        sprintf("%s [%-5s] [%-40.40s] %s\n", datetime, severity, to_s, msg)
      }
      @logger
    end
  end
end
