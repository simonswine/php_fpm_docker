# coding: utf-8
require 'php_fpm_docker/logging'

module PhpFpmDocker
  # Installs init script
  class Installer # rubocop:disable ClassLength
    extend Logging
    def self.run # rubocop:disable MethodLength, CyclomaticComplexity, PerceivedComplexity, LineLength,  AbcSize
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
    end
  end
end
