module PhpFpmDocker
  # Logging method for all classes
  module Logging
    def logger
      return @logger if @logger
      @logger = Logger.new 'test'
      outputter = Outputter.stdout
      outputter.formatter = PatternFormatter.new(
        pattern: "%l - #{self.class} - %m"
      )
      @logger.outputters = outputter
      @logger
    end
  end
end
