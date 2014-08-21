# coding: utf-8
require 'pathname'
require 'inifile'
require 'pp'
require 'logger'
require 'docker'

module PhpFpmDocker
  # Represent a single docker image
  class Launcher # rubocop:disable ClassLength
    attr_reader :docker_image, :php_cmd_path, :spawn_cmd_path

    def initialize(name) # rubocop:disable MethodLength
      @name = name

      # Create log dir if needed
      log_dir = Pathname.new('/var/log/php_fpm_docker')
      FileUtils.mkdir_p log_dir unless log_dir.directory?

      # Open logger
      @logger = Logger.new(log_dir.join("#{name}.log"), 'daily')
      @logger.info(to_s) { 'init' }

      begin
        test_directories

        # Parse config
        parse_config

        # Test docker image
        test_docker_image

      rescue RuntimeError => e
        @logger.fatal(to_s) { "Error while init: #{e.message}" }
        exit 1
      end
    end

    def run
      pid = fork do
        Signal.trap('USR1') do
          @logger.info(to_s) { 'Signal USR1 received reloading now' }
        end
        Signal.trap('TERM') do
          @logger.info(to_s) { 'Signal TERM received stopping me now' }
          sleep 3
          exit 0
        end
        while true
          sleep 5
        end
      end
      Process.detach(pid)
      pid
    end

    def init_pools
      @pools = []
      list_pool_configs.each do |pool|
        @pools << Pool.new(
            config_path: pool,
            launcher: self
        )
      end
    end

    def test_directories
      # Get config dirs and paths
      @conf_directory = Pathname.new('/etc/php_fpm_docker/conf.d').join(@name)
      fail "Config directory '#{@conf_directory}' not found" \
      unless @conf_directory.directory?

      @pools_directory = @conf_directory.join('pools.d')
      fail "Pool directory '#{@pools_directory}' not found" \
      unless @pools_directory.directory?

      @config_path = @conf_directory.join('config.ini')
    end

    def to_s
      "<Launcher:#{@name}>"
    end

    # Parse the config file for all pools
    def parse_config # rubocop:disable MethodLength
      # Test for file usability
      fail "Config file '#{@config_path}' not found"\
      unless @config_path.file?
      fail "Config file '#{@config_path}' not readable"\
      unless @config_path.readable?

      @ini_file = IniFile.load(@config_path)

      begin
        docker_image = @ini_file[:main]['docker_image']
        @docker_image = Docker::Image.get(docker_image)
        @logger.info(to_s) do
          "Docker image id=#{@docker_image.id[0..11]} name=#{docker_image}"
        end
      rescue NoMethodError
        raise 'No docker_image in section main in config found'
      rescue Docker::Error::NotFoundError
        raise "Docker_image '#{docker_image}' not found"
      rescue Excon::Errors::SocketError => e
        raise "Docker connection could not be established: #{e.message}"
      end
    end

    def docker_opts
      {
        'Image' => @docker_image.id
      }
    end

    def list_pool_configs
      Dir[@pools_directory.join('*.conf').to_s].map { |f| Pathname.new f }
    end

    # Docker init
    def test_docker_cmd(cmd) # rubocop:disable MethodLength
      opts = docker_opts
      opts['Cmd'] = cmd
      dict = {}

      cont = Docker::Container.create(opts)
      cont.start
      output = cont.attach
      dict[:ret_val] = cont.wait(5)['StatusCode']
      cont.delete(force: true)

      dict[:stdout] = output[0].first
      dict[:stderr] = output[1].first

      @logger.debug(to_s) do
        "cmd=#{cmd.join(' ')} ret_val=#{dict[:ret_val]}" \
        " stdout=#{dict[:stdout]} stderr=#{dict[:stderr]}"
      end

      dict
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
        next if /PHP \d+\.\d+\.\d+ \(cgi-fcgi\)/.match(result[:stdout]).nil?

        @php_cmd_path = php_cmd_path
        break
      end
      fail 'No usable fast-cgi enabled php found in image' if @php_cmd_path.nil?

      # Test if spawn-fcgi exists
      result = test_docker_cmd [:which, 'spawn-fcgi']
      fail 'No usable spawn-fcgi found in image' unless result[:ret_val] == 0
      @spawn_cmd_path = result[:stdout].strip
    end
  end
end
