# coding: utf-8
require 'php_fpm_docker/launcher'
require 'php_fpm_docker/pool'
require 'logger'

module PhpFpmDocker
  # Application that is used as init script
  class Application
    attr_reader :php_name
    def initialize
      @name = 'php_fpm_docker'
      @longname = 'PHP FPM Docker Wrapper'
      # Create log dir if needed
      log_dir = Pathname.new('/var/log/php_fpm_docker')
      FileUtils.mkdir_p log_dir unless log_dir.directory?

      # Init logger
      log_file = log_dir.join('wrapper.log')
      @logger = Logger.new(log_file, 'daily')
    end

    def install # rubocop:disable MethodLength, CyclomaticComplexity, PerceivedComplexity, LineLength,  AbcSize
      # Get launcher name
      begin
        puts 'Enter name of the php docker launcher instance:'
        name = $stdin.gets.chomp
        fail 'Only use these characters: a-z0-9-_.' \
          unless /^[a-z0-9\.\-_]+$/.match(name)
      rescue RuntimeError =>  e
        $stderr.puts(e.message)
        retry
      end

      # Get image name
      begin
        puts 'Enter name of the docker image to use:'
        image = $stdin.gets.chomp
        fail 'Only use these characters: a-z0-9-_./:' \
          unless /^[a-z0-9\.\-_\/\:]+$/.match(name)
      rescue RuntimeError =>  e
        $stderr.puts(e.message)
        retry
      end

      bin_name = 'php_fpm_docker'
      bin_path = nil?
      # Path
      begin
        ENV['PATH'].split(':').each  do |folder|
          path = File.join(folder, bin_name)
          if File.exist? path
            bin_path = path
            break
          end
        end

        if bin_path.nil?
          bin_path = File.expand_path(File.join(
            File.dirname(__FILE__),
            '..',
            '..',
            'bin',
            bin_name
          ))
        end

      rescue RuntimeError =>  e
        $stderr.puts(e.message)
      end

      puts image

      config_basepath = Pathname.new '/etc/php_fpm_docker/conf.d'
      config_dir = config_basepath.join name
      config_path = config_dir.join 'config.ini'
      config_pool = config_dir.join 'pools.d'
      config_content = <<eos
[main]
docker_image=#{image}
eos

      initd_name = "php_fpm_docker_#{name}"
      initd_path = Pathname.new File.join('/etc/init.d/', initd_name)
      initd_content = <<eos
#!/bin/sh
### BEGIN INIT INFO
# Provides:          #{initd_name}
# Required-Start:    $remote_fs $network
# Required-Stop:     $remote_fs $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts PHP Docker launcher #{name}
# Description:       Starts The PHP Docker launcher daemon #{name}
### END INIT INFO

NAME=#{name}
DAEMON=#{bin_path}


case "$1" in
    start)
  $DAEMON $NAME start
  ;;
    stop)
  $DAEMON $NAME stop
  ;;
    reload)
  $DAEMON $NAME reload
  ;;
    status)
  $DAEMON $NAME status
  ;;
    restart|force-reload)
  $DAEMON $NAME restart
  ;;
  *)
  echo "Usage: $0 {start|stop|status|restart|force-reload|reload}" >&2
  exit 1
  ;;
esac


eos
      puts "Creating init script in '#{initd_path}'"
      File.open(initd_path, 'w') do |file|
        file.write(initd_content)
      end
      File.chmod(0755, initd_path)

      unless config_dir.exist?
        puts "Creating config directory '#{config_dir}'"
        FileUtils.mkdir_p config_dir
      end
      unless config_pool.exist?
        puts "Creating pools directory '#{config_pool}'"
        FileUtils.mkdir_p config_pool
      end
      puts "Creating config file '#{config_path}'"
      File.open(config_path, 'w') do |file|
        file.write(config_content)
      end

      0
    end

    def start
      print "Starting #{full_name}: "
      $stdout.flush

      if running?
        puts 'already running'
        return 0
      end

      # init
      l = Launcher.new php_name

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

    def run
      method_to_call = parse_arguments(ARGV)
      exit send(method_to_call)
    rescue RuntimeError => e
      @logger.warn(php_name) { e.message }
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

      @logger.info(php_name) { "calling method #{method_to_call}" }

      method_to_call
    end

    def allowed_methods
      retval = public_methods(false)
      retval.delete(:run)
      retval.delete(:install)
      retval
    end

    def pid_file
      File.join('/var/run/', "#{@name}_#{php_name}.run")
    end

    def pid
      return nil unless File.exist? pid_file
      val = open(pid_file).read.strip.to_i
      return nil if val == 0
      val
    end

    def pid=(pid)
      if pid.nil?
        begin
          File.unlink pid_file
        rescue Errno::ENOENT
          @logger.debug("No pid file found: #{pid_file}")
        end
      else
        File.open pid_file, 'w' do |f|
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
