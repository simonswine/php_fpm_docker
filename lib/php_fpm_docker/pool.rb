# coding: utf-8
require 'pp'
require 'inifile'
require 'docker'

module PhpFpmDocker
  # A pool represent a single isolatet php web instance
  class Pool
    def initialize(opts)
      @config = opts[:config]
      @launcher = opts[:launcher]
      @name = opts[:name]
    end

    def docker_create_opts
      volumes = {}
      bind_mounts.each do |d|
        volumes[d] = {}
      end

      {
        'Image' => @launcher.docker_image.id,
        'Volumes' => volumes,
        'WorkingDir' => '/'
      }
    end

    def docker_start_opts
      binds = bind_mounts.map do |d|
        "#{d}:#{d}"
      end
      {
        'Binds' => binds
      }
    end

    def bind_mounts # rubocop:disable MethodLength
      ret_val = @launcher.bind_mounts
      ret_val << File.dirname(@config['listen'])

      @config['php_admin_value[open_basedir]'].split(':').each do |dir|
        [
          %r{(^/var/www/clients/client\d+/web\d+)},
          %r{(^/var/www/[^/]+)/web$}
        ].each do |regex|
          m = regex.match(dir)
          ret_val << m[1] unless m.nil?
        end
      end

      ret_val.uniq
    end

    def root_dir
      File.dirname(@config['php_admin_value[open_basedir]'].split(':').first)
    end

    def socket_dir
      File.dirname(@config['listen'])
    end

    # Build the spawn command
    def spawn_command  # rubocop:disable MethodLength
      listen_uid = Etc.getpwnam(@config['listen.owner']).uid.to_s
      listen_gid = Etc.getgrnam(@config['listen.group']).gid.to_s
      uid = Etc.getpwnam(@config['user']).uid.to_s
      gid = Etc.getgrnam(@config['group']).gid.to_s

      [
        @launcher.spawn_cmd_path,
        '-s', @config['listen'],
        '-U', listen_uid,
        '-G', listen_gid,
        '-M', '0660',
        '-u', uid,
        '-g', gid,
        '-C', '4',
        '-n'
      ]
    end

    def php_command
      admin_options = []
      @config.each_key do |key|
        m = /^php_admin_value\[([^\]]+)\]$/.match(key)
        next if m.nil?

        admin_options << '-d'
        admin_options << "#{m[1]}=#{@config[key]}"

      end

      [@launcher.php_cmd_path] + admin_options
    end

    def start
      return unless enabled?
      create_opts = docker_create_opts
      create_opts['Cmd'] = spawn_command + ['--'] + php_command

      @container = Docker::Container.create(create_opts)
      @container.start(docker_start_opts)
    end

    def check
      #TODO Implement check
    end

    def stop
      return unless enabled?
      @container.delete(force: true) unless @container.nil?
    end

    def to_s
      "<Pool:#{@name}>"
    end

    def enable
      @enabled = true
    end

    def disable
      @enabled = false
    end

    def enabled?
      @enabled ||= true
    end

  end
end
