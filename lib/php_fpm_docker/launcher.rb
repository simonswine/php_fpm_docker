# coding: utf-8
require 'pathname'
require 'inifile'
require 'pp'
require 'logger'
require 'docker'
require 'digest'

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

      test
    end

    def test
      test_directories

      # Parse config
      parse_config

      # Test docker image
      test_docker_image

    rescue RuntimeError => e
      @logger.fatal(to_s) { "Error while init: #{e.message}" }
      exit 1
    end

    def run
      start_pools

      pid = fork do
        fork_run
      end
      Process.detach(pid)
      pid
    end

    def fork_run
      Signal.trap('USR1') do
        @logger.info(to_s) { 'Signal USR1 received reloading now' }
        reload_pools
      end
      Signal.trap('TERM') do
        @logger.info(to_s) { 'Signal TERM received stopping me now' }
        stop_pools
        exit 0
      end
      Kernel.loop do
        check_pools
        sleep 1
      end
    end

    def start_pools
      @pools = {}
      reload_pools
    end

    def stop_pools
      reload_pools({})
    end

    def create_missing_pool_objects
      return if @pools.nil?
      return if @pools_old.nil?
      (@pools.keys & @pools_old.keys).each do |hash|
        @pools[hash][:object] = @pools_old[hash][:object]
      end
    end

    def move_existing_pool_objects
      return if @pools.nil?
      @pools.keys.each do |hash|
        pool = @pools[hash]
        # skip if there's already an object
        next if pool.key?(:object)
        pool[:object] = Pool.new(
          config: pool[:config],
          name: pool[:name],
          launcher: self
        )
      end
    end

    def reload_pools(pools = nil)
      @pools_old = @pools
      if pools.nil?
        @pools = pools_from_config
      else
        @pools = pools
      end

      move_existing_pool_objects
      create_missing_pool_objects

      # Pools to stop
      pools_action(@pools_old, @pools_old.keys - @pools.keys, :stop)

      # Pools to start
      pools_action(@pools, @pools.keys - @pools_old.keys, :start)
    end

    def check_pools
      'do nothing'
    end

    def check_pools_n
      pools_action(@pools, @pools.keys, :check)
    end

    def pools_action(pools, pools_hashes, action)
      message = ''
      if pools_hashes.length > 0
        message << "Pools to #{action}: "
        message <<  pools_hashes.map { |p| pools[p][:name] }.join(', ')
        pools_hashes.each do |pool_hash|
          pool = pools[pool_hash]
          begin
            pool[:object].send(action)
          rescue => e
            @logger.warn(pool[:object].to_s) do
              "Failed to #{action}: #{e.message}"
            end
          end
        end
      else
        message << "No pools to #{action}"
      end
      @logger.info(to_s) { message }
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

    # Get neccessary bind mounts
    def bind_mounts
      @ini_file[:main]['bind_mounts'].split(',') || []
    end

    # Get webs base path
    def web_path
      Pathname.new(@ini_file[:main]['web_path'] || '/var/www')
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

    # Reads config sections from a inifile
    def pools_config_content_from_file(config_path)
      ini_file = IniFile.load(config_path)

      ret_val = []
      ini_file.each_section do |section|
        ret_val << [section, ini_file[section]]
      end
      ret_val
    end

    # Merges config sections form all inifiles
    def pools_config_contents
      ret_val = []

      # Loop over
      Dir[@pools_directory.join('*.conf').to_s].each do |config_path|
        ret_val += pools_config_content_from_file(config_path)
      end
      ret_val
    end

    # Hashes configs to detect changes
    def pools_from_config
      configs = {}

      pools_config_contents.each do |section|
        # Hash section name and content
        d = Digest::SHA2.new(256)
        hash = d.reset.update(section[0]).update(section[1].to_s).to_s

        configs[hash] = {
          name: section[0],
          config: section[1]
        }
      end
      configs
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

      @logger.debug(to_s) do
        "cmd=#{cmd.join(' ')} ret_val=#{dict[:ret_val]}" \
        " stdout=#{dict[:stdout]} stderr=#{dict[:stderr]}"
      end

      dict
    rescue Docker::Error::TimeoutError => e
      if (tries -= 1) > 0
        cont.delete(force: true) if cont.nil?
        @logger.debug(to_s) { 'ran into timeout retry' }
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
  end
end
