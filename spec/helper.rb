module Helper

  def create_config(opts={})
    options = {
      launchers: 2,
      pools: 4,
    }
    options.merge! opts

    create_config_global options
    create_config_launcher options
  end

  def create_config_launcher(options)
    for i in 1..options[:launchers] do
      write_file(
        options[:config_dir].join("launcher#{i}",'config.ini'),
        "image_name = image/launcher#{i}",
      )
      create_config_pool(i,options)
    end
  end

  def create_config_pool(i,options)
    for j in 1..options[:pools] do
      write_file(
        options[:config_dir].join("launcher#{i}",'pools.d',"web#{j}.conf"),
        [
          "[web#{j}]",
          "listen = /var/lib/php5-fpm/web#{j}.sock",
          "listen.owner = luser#{j}",
        "listen.group = lgroup#{j}",
        "listen.mode = 0660",
        "user = user#{j}",
        "group = group#{j}",
        "php_admin_value[open_basedir] = /var/www/webs/clients/client#{j}/web#{j}/web:/var/www/web#{j}domain.com/web:/usr/share/php5:/usr/share/php",
        ].join("\n")
      )
    end
  end

  def create_config_global(options)
    write_file(
      options[:config_dir].join('config.ini'),
      [
        "web_path = #{options[:web_dir]}",
      ]
    )
  end

  def write_file(path, content)
    FileUtils.mkdir_p path.parent unless path.parent.directory?
    File.open(path, "w") do |f|
        f.write content
    end
  end

  def dbl_launcher_options
    {
      :bind_mounts => ['/mnt/bind'],
      :web_path => '/var/webpath',
      :docker_image => dbl_docker_image,
      :spawn_cmd_path => '/usr/bin/fcgi-bin',
      :php_cmd_path => '/usr/bin/php',
    }
  end

  def dbl_launcher
    return @dbl_launcher unless @dbl_launcher.nil?
    @dbl_launcher = instance_double('PhpFpmDocker::Launcher', dbl_launcher_options)
  end

  def dbl_docker_image
    return @dbl_docker_image unless @dbl_docker_image.nil?
    @dbl_docker_image = instance_double('PhpFpmDocker::DockerImage',
        :create => nil,
    )
    @dbl_docker_image
  end

  def dbl_docker_container
    return @dbl_docker_container unless @dbl_docker_container.nil?
    @dbl_docker_container = double('PhpFpmDocker::DockerContainer',
        :running? => nil,
    )
    @dbl_docker_container
  end

  def dbl_logger
    return @dbl_logger unless @dbl_logger.nil?
    logger=double
    [:debug,:error,:warn,:info,:fatal].each do |loglevel|
      allow(logger).to receive(loglevel)
    end
    @dbl_logger ||= logger
  end

  def mock_users
    allow(Etc).to receive(:getpwnam) do |user|
      uid = @users.select do |key, value|
        value == user
      end.first.first.to_i
      d = double(user)
      allow(d).to receive(:uid).and_return(uid)
      d
    end
  end

  def mock_groups
    allow(Etc).to receive(:getgrnam) do |group|
      gid = @groups.select do |key, value|
        value == group
      end.first.first.to_i
      d = double(group)
      allow(d).to receive(:gid).and_return(gid)
      d
    end
  end

  def mock_logger(c)
    allow(c).to receive(:logger).and_return(dbl_logger)
  end

  def deep_clone(i)
    Marshal.load(Marshal.dump(i))
  end

  def inst_set(var, value)
    if value.nil?
      value=nil
    else
      if value.is_a? Hash or value.is_a? Array
        value = deep_clone value
      else
        value
      end
    end
    a_i.instance_variable_set(var, value)
  end

  def inst_get(var)
    a_i.instance_variable_get(var)
  end

  def get_method_name
    name = self.class.metadata[:full_description].split('#')[1]
    name = name.split.first
    return name.to_sym
  end

  def method(*args)
    func = get_method_name
    a_i.instance_exec(func) {|f| send(f,*args)}
  end
end
