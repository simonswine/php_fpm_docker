# coding: utf-8
require 'php_fpm_docker/launcher'
require 'php_fpm_docker/pool'
require 'php_fpm_docker/logging'

module PhpFpmDocker

  # Application that is used as init script
  class Application # rubocop:disable ClassLength

    @@log_path = nil

    def self.log_path
      @@log_path ||= log_dir_path.join('wrapper.log')
    end

    def self.log_path=(path)
      # TODO: Check if input is pathname
      @@log_path = path
    end

    def self.log_dir_path
      Pathname.new('/var/log/php_fpm_docker')
    end

    include Logging

    attr_reader :php_name

    def initialize
      @name = 'php_fpm_docker'
      @longname = 'PHP FPM Docker Wrapper'
    end


    def log_path
      Application.log_dir_path.join('wrapper.log')
    end

    def start
      print "Starting #{full_name}: "
      $stdout.flush

      if running?
        puts 'already running'
        return 0
      end

      # init
      l = Launcher.new php_name, self

      # run daemon
      self.pid = l.run

      puts "done (pid=#{pid})"
      0
    end

    def stop
      print "Stopping #{full_name}: "
      $stdout.flush

      unless running?
        puts 'not running'
        return 0
      end

      Process.kill('TERM', pid)

      count = 0
      while running? && count <= 50
        sleep 0.2
        count += 1
      end

      if running?
        puts 'still running'
        return 1
      else
        self.pid = nil
        puts 'stopped'
        return 0
      end
    end

    def status
      print "Status of #{full_name}: "
      $stdout.flush

      if running?
        puts 'running'
        return 0
      else
        puts 'not running'
        return 3
      end
    end

    def reload
      print "Reloading #{full_name}: "
      $stdout.flush

      unless running?
        puts 'not running'
        return 0
      end

      Process.kill('USR1', pid)
      puts 'done'
      0
    end

    def config_dir_path
      Pathname.new('/etc/php_fpm_docker/conf.d')
    end

    def bind_mounts
      []
    end

    def web_path
      Pathname.new('/var/www')
    end

    def restart
      ret_val = stop
      return ret_val if ret_val != 0
      start
    end

    def help
      $stderr.puts(
        "Usage: #{php_name} $NAME {#{allowed_methods.join '|'}}"
      )
      $stderr.puts("       #{php_name} install")
    end

    def run(args = ARGV)
      method_to_call = parse_arguments(args)
      exit send(method_to_call)
    rescue RuntimeError => e
      logger.warn(php_name) { e.message }
      help
      exit 3
    end

    private

    attr_writer :php_name

    # Get php name from scriptname
    def full_name
      "#{@longname} '#{php_name}'"
    end

    def parse_arguments(args)
      # no args
      fail 'no argument' if args.first.nil?

      # install mode
      return :install if args.first == 'install'

      # get correct php name
      self.php_name = args.first

      fail 'wrong argument count' if args[1].nil?

      method_to_call = args[1].to_sym

      fail "unknown method #{args[1]}" \
        unless allowed_methods.include?(method_to_call)

      logger.info(php_name) { "calling method #{method_to_call}" }

      method_to_call
    end

    def allowed_methods
      retval = public_methods(false)
      [
        :install,
        :run,
        :bind_mounts,
        :config_dir_path,
        :web_path,
        :help,
        :php_name
      ].each do |e|
        retval.delete e
      end
      retval
    end

    def pid_dir_path
      Pathname.new '/var/run'
    end

    def pid_path
      pid_dir_path.join("#{@name}_#{php_name}.run")
    end

    def pid
      return nil unless File.exist? pid_path
      val = open(pid_path).read.strip.to_i
      return nil if val == 0
      val
    end

    def pid=(pid)
      if pid.nil?
        begin
          File.unlink pid_path
        rescue Errno::ENOENT
          logger.debug("No pid file found: #{pid_path}")
        end
      else
        dir = pid_path.parent
        FileUtils.mkdir_p dir unless dir.directory?
        File.open pid_path, 'w' do |f|
          f.write pid
        end
      end
    end

    def running?
      return false if pid.nil?
      begin
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end
    end
  end
end
