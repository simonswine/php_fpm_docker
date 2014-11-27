# coding: utf-8
require 'docker'
require 'php_fpm_docker/logging'

module PhpFpmDocker
  # Wraps the docker connection
  class DockerImage
    include Logging

    def initialize(image_name)
      @image_name = image_name
    end

    def id
      image.id
    end

    def image
      @image ||= fetch_image
    end

    # Fetches image id form docker server
    def fetch_image
      image = Docker::Image.get(@image_name)
      logger.info do
        "Docker image id=#{image.id[0..7]} name=#{@image_name}"
      end
      image
    rescue Docker::Error::NotFoundError
      raise "Docker_image '#{@image_name}' not found"
    rescue Excon::Errors::SocketError => e
      raise "Docker connection could not be established: #{e.message}"
    end

    # Run command in container
    def cmd(*args)
      DockerContainer.cmd(self, *args)
    end

    # Docker init
    def test_docker_cmd(cmd) # rubocop:disable MethodLength
      # retry this block 3 times
      tries ||= 3

      opts = docker_opts
      opts['Cmd'] = cmd
      dict = {}

      # Set timeout
      Docker.options[:read_timeout] = 2

      cont = Docker::Container.create(opts)
      cont.start
      output = cont.attach
      dict[:ret_val] = cont.wait(5)['StatusCode']
      cont.delete(force: true)

      dict[:stdout] = output[0].first
      dict[:stderr] = output[1].first

      # Set timeout
      Docker.options[:read_timeout] = 15

      logger.debug(to_s) do
        "cmd=#{cmd.join(' ')} ret_val=#{dict[:ret_val]}" \
        " stdout=#{dict[:stdout]} stderr=#{dict[:stderr]}"
      end

      dict
    rescue Docker::Error::TimeoutError => e
      if (tries -= 1) > 0
        cont.delete(force: true) if cont.nil?
        logger.debug(to_s) { 'ran into timeout retry' }
        retry
      end
      raise e
    end

    # Testing the docker image if i can be used
    def test_docker_image # rubocop:disable MethodLength
      # Test possible php commands
      ['php-cgi', 'php5-cgi', 'php', 'php5'].each do |php_cmd|
        result = test_docker_cmd [:which, php_cmd]

        next unless result[:ret_val] == 0

        php_cmd_path = result[:stdout].strip

        result = test_docker_cmd [php_cmd_path, '-v']

        next unless result[:ret_val] == 0
        php_version_re = /PHP [A-Za-z0-9\.\-\_]+ \(cgi-fcgi\)/
        next if php_version_re.match(result[:stdout]).nil?

        @php_cmd_path = php_cmd_path
        break
      end
      fail 'No usable fast-cgi enabled php found in image' if @php_cmd_path.nil?

      # Test if spawn-fcgi exists
      result = test_docker_cmd [:which, 'spawn-fcgi']
      fail 'No usable spawn-fcgi found in image' unless result[:ret_val] == 0
      @spawn_cmd_path = result[:stdout].strip
    end

    def docker_image_get
    end

    def docker_opts
      {
        'Image' => @docker_image.id
      }
    end
  end
end
