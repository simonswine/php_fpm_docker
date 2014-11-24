# coding: utf-8
require 'pp'
require 'inifile'
require 'docker'

module PhpFpmDocker
  # A pool represent a single isolated PHP web instance
  class Pool
    attr_reader :enabled
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

    # Return web path regexs
    def web_path_regex
      [
        %r{(^#{@launcher.web_path}/clients/client\d+/web\d+)},
        %r{(^#{@launcher.web_path}/[^/]+)/web$}
      ]
    end

    def valid_web_paths
      ret_val = []
      open_base_dirs.map do |dir|
        web_path_regex.each do |regex|
          m = regex.match(dir)
          ret_val << m[1] unless m.nil?
        end
      end
      ret_val
    end

    # Find out bind mount paths
    def bind_mounts
      ret_val = @launcher.bind_mounts
      ret_val << File.dirname(@config['listen'])
      ret_val += valid_web_paths
      ret_val.uniq
    end

    def open_base_dirs
      @config['php_admin_value[open_basedir]'].split(':')
    end

    def root_dir
      max(valid_web_paths)
    end

    def socket_dir
      File.dirname(@config['listen'])
    end

    def uid_from_user(user)
      Etc.getpwnam(user).uid
    end

    def gid_from_group(group)
      Etc.getgrnam(group).gid
    end

    def listen_uid
      uid_from_user(@config['listen.owner'])
    end

    def listen_gid
      gid_from_group(@config['listen.group'])
    end

    def uid
      uid_from_user(@config['user'])
    end

    def gid
      gid_from_group(@config['group'])
    end

    # Build the spawn command
    def spawn_command
      [
        @launcher.spawn_cmd_path,
        '-s', @config['listen'],
        '-U', listen_uid.to_s,
        '-G', listen_gid.to_s,
        '-M', '0660',
        '-u', uid.to_s,
        '-g', gid.to_s,
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
      @enabled = true
      create_opts = docker_create_opts
      create_opts['Cmd'] = spawn_command + ['--'] + php_command

      @container = Docker::Container.create(create_opts)
      @container.start(docker_start_opts)
    end

    def container_running?
      return false if @container.nil?
      begin
        return @container.info['State']['Running']
      rescue NoMethodError
        return false
      end
    end

    def check
      return unless @enabled && !container_running?
      stop
      start
    end

    def stop
      @enabled = false
      @container.delete(force: true) unless @container.nil?
    end

    def to_s
      "<Pool:#{@name}>"
    end
  end
end
