# coding: utf-8
require 'pathname'
require 'php_fpm_docker/config_parser'
require 'php_fpm_docker/logging'

module PhpFpmDocker
  # Represent a single docker image
  class Launcher # rubocop:disable ClassLength
    include Logging

    attr_reader :docker_image, :php_cmd_path, :spawn_cmd_path

    def initialize(name, app) # rubocop:disable MethodLength
      @name = name
      @app = app
      Application.log_path = Application.log_dir_path.join("#{@name}")
    end

    def test
      test_directories

      # Parse config
      config

    rescue RuntimeError => e
      logger.fatal(to_s) { "Error while init: #{e.message}" }
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
        logger.info(to_s) { 'Signal USR1 received reloading now' }
        reload_pools
      end
      Signal.trap('TERM') do
        logger.info(to_s) { 'Signal TERM received stopping me now' }
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
        @pools = pools_config
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
            logger.warn(pool[:object].to_s) do
              "Failed to #{action}: #{e.message}"
            end
          end
        end
      else
        message << "No pools to #{action}"
      end
      logger.info(to_s) { message }
    end

    def test_directories
      fail "Config directory '#{config_dir_path}' not found" \
      unless config_dir_path.directory?

      fail "Pool directory '#{pools_dir_path}' not found" \
      unless pools_dir_path.directory?
    end

    def to_s
      "<Launcher:#{@name}>"
    end

    # Get neccessary bind mounts
    def bind_mounts
      begin
        mine = config['global']['bind_mounts']
        mine = mine.split(',')
      rescue NoMethodError
        mine = nil
      end
      parent = @app.bind_mounts
      return parent if mine.nil?
      mine.map!(&:strip)
      (mine + parent).uniq
    end

    def config_dir_path
      @app.config_dir_path.join @name
    end

    def pools_dir_path
      config_dir_path.join('pools.d')
    end

    def config_path
      config_dir_path.join('config.ini')
    end

    # Get webs base path
    def web_path
      path = config[:main]['web_path']
      fail TypeError('Empty string') if path.length == 0
      Pathname.new(path)
    rescue NoMethodError, TypeError
      @app.web_path
    end

    def pools_config
      @pools_config ||= ConfigParser.new(pools_dir_path)
      @pools_config.pools
    end

    def config
      @config ||= ConfigParser.new(config_path)
      @config.config
    end

    def docker_image
      @docker_image ||= docker_image_get
    end
  end
end
