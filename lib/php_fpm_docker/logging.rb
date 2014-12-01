require 'logger'
require 'php_fpm_docker'

module PhpFpmDocker
  # Logging method for all classes
  module Logging
    def logger
      return @logger if @logger
      path = ::PhpFpmDocker::Application.log_path
      if path.is_a? Pathname
        dir = path.parent
        FileUtils.mkdir_p dir unless dir.directory?
      end
      @logger = ::Logger.new path
      @logger.formatter = proc { |severity, datetime, _progname, msg|
        sprintf("%s [%-5s] [%-40.40s] %s\n", datetime, severity, to_s, msg)
      }
      @logger
    end
  end
end
