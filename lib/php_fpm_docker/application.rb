# coding: utf-8
require 'php_fpm_docker/launcher'
require 'php_fpm_docker/pool'

module PhpFpmDocker
  # Application that is used as init script
  class Application
    def run
      @launcher = Launcher.new 'php_4.4'
      puts 'Run'
    end
  end
end
