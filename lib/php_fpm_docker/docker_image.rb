# coding: utf-8
require 'docker'
require 'php_fpm_docker/logging'

module PhpFpmDocker
  # Wraps the docker connection
  class DockerImage
    include Logging
    attr_reader :name
    def self.available?
      Docker.version
      true
    rescue Excon::Errors::SocketError
      false
    end

    def initialize(name)
      @name = name
    end

    def id
      image.id
    end

    def image
      @image ||= fetch_image
    end

    # Fetches image id form docker server
    def fetch_image
      image = Docker::Image.get(@name)
      logger.info do
        "fetched docker image id=#{image.id[0..7]}"
      end
      image
    rescue Docker::Error::NotFoundError
      raise "Docker_image '#{@name}' not found"
    rescue Excon::Errors::SocketError => e
      raise "Docker connection could not be established: #{e.message}"
    end

    # Run command in container
    def cmd(*args)
      DockerContainer.cmd(self, *args)
    end

    def create(*args)
      DockerContainer.create(self, *args)
    end

    def to_s
      "#<DockerImage:#{name}>"
    end

    def detect_output
      @detect_output ||= detect_fetch
    end

    def spawn_fcgi_path
      detect_find_path :spawn_fcgi_path
    end

    def php_fcgi?
      php_version_re = /PHP ([A-Za-z0-9\.\-\_]+) \(cgi-fcgi\)/
      php_version_output = detect_output[2..-1].join("\n")
      match = php_version_re.match(php_version_output)
      return false if match.nil?
      true
    end

    def php_version
      php_version_re = /PHP ([A-Za-z0-9\.\-\_]+) /
      php_version_output = detect_output[2..-1].join("\n")
      match = php_version_re.match(php_version_output)
      return match[1] unless match.nil?
      nil
    end

    def php_path
      detect_find_path :php_path
    end

    def detect_find_path(sym)
      detect_output.each do |line|
        m = /^#{sym.to_s}=(.*)/.match line
        return m[1] unless m.nil?
      end
      nil
    end

    private

    def detect_fetch
      output = cmd(['/bin/sh', '-c', detect_cmd])
      output[:stdout].split("\n")
    end

    def detect_cmd
      cmds = []
      cmds << detect_binary_shell(
        :spawn_fcgi,
        ['spawn-fcgi']
      )
      cmds << detect_binary_shell(
        :php,
        ['php-cgi', 'php5-cgi', 'php', 'php5']
      )
      cmds << "[ -n \"${PHP_PATH}\" ] && ${PHP_PATH} -v"
      cmds.join ';'
    end

    def detect_binary_shell(name, basenames)
      var = "#{name.upcase}_PATH"
      which = "#{var}=$(which %s 2> /dev/null)"
      template = "[ $? -eq 0 ] || #{which}"

      # First element
      ret_val = [which % basenames.first]

      # Loop through basenames from second
      basenames[1..-1].each do |base|
        ret_val << template % base
      end

      ret_val << "echo \"#{var.downcase}=${#{var}}\""

      ret_val
    end
  end
end
