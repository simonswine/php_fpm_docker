require 'spec_helper'
require 'php_fpm_docker/pool'

LAUNCHER_WEB_PATH = '/var/webpath'
LAUNCHER_BIND_MOUNTS = ['/mnt/bind']
LAUNCHER_SPAWN_FCGI = '/usr/bin/fcgi-bin'
LAUNCHER_PHP = '/usr/bin/php'

describe PhpFpmDocker::Pool do

  # Default config
  let(:default_config) {
    {
      'listen' => '/tmp/name2.sock',
      'listen.owner' => 'user1',
      'listen.group' => 'group1',
      'listen.mode' => '0660',
      'user' => 'user2',
      'group' => 'group2',
      'php_admin_value[open_basedir]' => [
        '/mnt/invalid/not_me_test',
        File.join(LAUNCHER_WEB_PATH,'test123','web'),
        File.join(LAUNCHER_WEB_PATH,'clients','client123','web2','web'),
      ].join(':'),
    }
  }

  # Mock Etc (getuid and getpwdid)
  before (:example) {
    # mock users
    user1 = double
    allow(user1).to receive(:uid).and_return(1001)
    user2 = double
    allow(user2).to receive(:uid).and_return(1002)
    allow(Etc).to receive(:getpwnam).with('user1').and_return(user1)
    allow(Etc).to receive(:getpwnam).with('user2').and_return(user2)
    # mock groups
    group1 = double
    allow(group1).to receive(:gid).and_return(1001)
    group2 = double
    allow(group2).to receive(:gid).and_return(1002)
    allow(Etc).to receive(:getgrnam).with('group1').and_return(group1)
    allow(Etc).to receive(:getgrnam).with('group2').and_return(group2)
  }

  # Mock Docker
  before (:example){
    @dbl_docker = class_double('Docker').as_stubbed_const()
    @dbl_docker_container = class_double('Docker::Container').as_stubbed_const()
  }

  # Mock launcher
  let(:launcher) {
    l = double

    # respond with global bind mounts
    allow(l).to receive(:bind_mounts).and_return(LAUNCHER_BIND_MOUNTS)

    # respond with webpath
    allow(l).to receive(:web_path).and_return(LAUNCHER_WEB_PATH)

    ## Mock docker image
    i = double
    allow(i).to receive(:id).and_return('deadbeef')
    # respond with image
    allow(l).to receive(:docker_image).and_return(i)

    # respond spwan fcgi path
    allow(l).to receive(:spawn_cmd_path).and_return(LAUNCHER_SPAWN_FCGI)

    # respond php path
    allow(l).to receive(:php_cmd_path).and_return(LAUNCHER_PHP)

    l
  }

  describe 'pool1 with default values' do
    let (:p) {
      p = described_class.new({
        :name => 'pool1',
        :config => default_config,
        :launcher => launcher,
      })
    }
    it "parse correct uid" do
      expect(p.uid).to eq(1002)
    end
    it "parse correct gid" do
      expect(p.gid).to eq(1002)
    end
    it "parse correct listen_uid" do
      expect(p.listen_uid).to eq(1001)
    end
    it "parse correct listen_gid" do
      expect(p.listen_gid).to eq(1001)
    end
    describe "#spawn_command" do
      before (:example) {
        @list = p.spawn_command
      }
      it 'list include spawn_fcgi' do
          expect(@list).to include(LAUNCHER_SPAWN_FCGI)
      end
      it 'list include socket path' do
          expect(@list).to include(default_config['listen'])
      end
      it 'list is flat' do
        expect(@list.flatten).to eq(@list)
      end
      it 'list is string only' do
        @list.each do |elem|
          expect(elem).to be_a(String)
        end
      end
    end
    describe "#bind_mounts" do
      let (:bind_mounts) {
        p.bind_mounts
      }
      it "not raise error" do
          expect{bind_mounts}.not_to raise_error
      end
      it "include socket directory" do
          expect(bind_mounts).to include(File.dirname(default_config['listen']))
      end
      it "include web root directories" do
        # get valid open_base_dirs
        default_config['php_admin_value[open_basedir]'].split(':')[1..-1].each do |dir|
          expect(bind_mounts).to include(File.dirname(dir))
        end
      end
      it "not include fake directories" do
        dir = default_config['php_admin_value[open_basedir]'].split(':').first
        expect(bind_mounts).not_to include(dir)
        expect(bind_mounts).not_to include(File.dirname(dir))
      end
    end
    describe "#php_command" do
      before (:example) {
        @list = p.php_command
      }
      it 'list include php cmd' do
          expect(@list).to include(LAUNCHER_PHP)
      end
      it 'list is flat' do
        expect(@list.flatten).to eq(@list)
      end
      it 'list is string only' do
        @list.each do |elem|
          expect(elem).to be_a(String)
        end
      end
    end
    describe "#docker_create_opts" do
      let (:docker_create_opts) {
        p.docker_create_opts
      }
      it "not raise error" do
          expect{docker_create_opts}.not_to raise_error
      end
      it "include php" do
          expect(docker_create_opts['Image']).to eq('deadbeef')
      end
    end
    describe "#start" do
      let (:method) {
        p.start
      }
      before (:example) {
        # catch upstream calls
        @spawn_list = ['spawn','spawn_args']
        @php_list = ['php','php_args']
        allow(p).to receive(:spawn_command).and_return(@spawn_list)
        allow(p).to receive(:php_command).and_return(@php_list)
        allow(p).to receive(:docker_create_opts).and_return({})
        allow(p).to receive(:docker_start_opts).and_return({})
      }
      it "starts container" do
        # container instance
        dbl_c_inst = double
        expect(dbl_c_inst).to receive(:start).with({})
        expect(@dbl_docker_container).to receive(:create).and_return(dbl_c_inst)
        method
      end
      it "build cmd correctly" do
        # container instance
        dbl_c_inst = double
        allow(dbl_c_inst).to receive(:start).with({})
        hash = hash_including('Cmd' => (@spawn_list + ['--'] + @php_list))
        expect(@dbl_docker_container).to receive(:create).with(hash).and_return(dbl_c_inst)
        method
      end
      it 'enables the pool' do
        # container instance
        dbl_c_inst = double
        expect(dbl_c_inst).to receive(:start).with({})
        expect(@dbl_docker_container).to receive(:create).and_return(dbl_c_inst)
        method
        # container class
        expect(p.enabled).to eq(true)
      end
    end
    describe "#stop" do
      it "stops existing container" do
        # container instance
        dbl_c_inst = double
        allow(dbl_c_inst).to receive(:delete).with(hash_including(force: true))
        p.instance_variable_set(:@container, dbl_c_inst)
        p.stop
        expect(p.enabled).to eq(false)
      end
      it "doesn't stop non-existing container" do
        p.instance_variable_set(:@container, nil)
        p.stop
        expect(p.enabled).to eq(false)
      end
    end
    describe "#container_running?" do
      it "container is nil" do
        expect(p.container_running?).to eq(false)
      end
      it "container is running" do
        dbl_c_inst = double
        allow(dbl_c_inst).to receive(:info).and_return({'State' => { 'Running' => true }})
        p.instance_variable_set(:@container, dbl_c_inst)
        expect(p.container_running?).to eq(true)
      end
      it "container is not running" do
        dbl_c_inst = double
        allow(dbl_c_inst).to receive(:info).and_return({'State' => { 'Running' => false }})
        p.instance_variable_set(:@container, dbl_c_inst)
        expect(p.container_running?).to eq(false)
      end
    end
    describe "#check" do
      [ # enabled, running, restart
        [true,true,false],
        [false,true,false],
        [false,false,false],
        [true,false,true],
      ].each do |enabled,running,restart|
        it "enabled=#{enabled} and running=#{running} -> restart=#{restart}" do
          allow(p).to receive(:'container_running?').and_return(running)
          p.instance_variable_set(:@enabled, enabled)

          # container
          dbl_c_inst = double
          p.instance_variable_set(:@container, dbl_c_inst)

          if restart
            expect(p).to receive(:stop)
            expect(p).to receive(:start)
          end
          p.check
        end
      end
    end
  end
end
