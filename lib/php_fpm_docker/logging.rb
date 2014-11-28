require 'logger'
require 'php_fpm_docker'

module PhpFpmDocker
  # Logging method for all classes
  module Logging
    def logger
      return @logger if @logger
      if Application.log_path.is_a? Pathname
        dir = Application.log_path.parent
        FileUtils.mkdir_p dir unless dir.directory?
      end
      @logger = ::Logger.new Application.log_path
      @logger.formatter = proc { |severity, datetime, _progname, msg|
        sprintf("%s [%-5s] [%-40.40s] %s\n", datetime, severity, to_s, msg)
      }
      @logger
    end
  end
end
