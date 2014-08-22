# coding: utf-8
require 'php_fpm_docker/launcher'
require 'php_fpm_docker/pool'
require 'logger'

module PhpFpmDocker
  # Application that is used as init script
  class Application
    @@name = 'php_fpm_docker'
    @@longname = 'PHP FPM Docker Wrapper'
    def initialize
      # Create log dir if needed
      log_dir = Pathname.new('/var/log/php_fpm_docker')
      FileUtils.mkdir_p log_dir unless log_dir.directory?

      # Init logger
      log_file = log_dir.join('wrapper.log')
      @logger = Logger.new(log_file, 'daily')
    end

    def start
      print "Starting #{full_name}: "
      $stdout.flush

      if running?
        puts 'already running'
        return 0
      end

      # init
      l = Launcher.new @php_name

      # run daemon
      self.pid = l.run

      puts "done (pid=#{pid})"
      return 0
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
      while running? and count <= 50
        sleep 0.2
        count += 1
      end

      if running?
        puts 'still running'
        return 1
      else
        self.pid=nil
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
      return 0
    end

    def restart
      ret_val = stop
      return ret_val if ret_val != 0
      start
    end

    def run
      # get correct php name
      @php_name = php_name

      # allowed arguments
      allowed_methods = public_methods(false)
      allowed_methods.delete(:run)

      begin
        fail 'no argument' if ARGV.first.nil?

        method_to_call = ARGV.first.to_sym

        fail "unknown method #{ARGV.first}" unless allowed_methods.include?(method_to_call)

        @logger.info(@php_name) { "calling method #{method_to_call}" }

        exit send(method_to_call)

      rescue RuntimeError => e
        @logger.warn(@php_name) { e.message }
        $stderr.puts("Usage: #{script_name} {#{allowed_methods.join '|'}}")
        exit 3
      end
    end

    private
    # Get php name from scriptname
    def php_name
      m = /^php_fpm_docker_([a-zA-Z0-9_\.\-]{3,})$/.match(script_name)
      if m
        m[1]
      else
        nil
      end
    end

    def full_name
      "#{@@longname} '#{@php_name}'"
    end

    # Get scriptname from argv[0]
    def script_name
      File.basename($PROGRAM_NAME)
    end

    def pid_file
      File.join('/var/run/', "#{script_name}.run")
    end

    def pid
      return nil unless File.exist? pid_file
      open(pid_file).read.strip.to_i
    end

    def pid=(pid)
      if pid.nil?
        begin
          File.unlink pid_file
        rescue Errno::ENOENT
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
