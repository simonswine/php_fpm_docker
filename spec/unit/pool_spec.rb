require 'spec_helper'
require 'php_fpm_docker/pool'


describe PhpFpmDocker::Pool do
  before(:example) do
    @users = {
      1001 => 'user1',
      1002 => 'user2',
    }
    @groups = {
      1001 => 'group1',
      1002 => 'group2',
    }
    mock_users
    mock_groups
  end

  # Default instance
  let (:a_i){
    i = described_class.new({
      :name => 'pool1',
      :config => default_config,
      :launcher => dbl_launcher,
    })
    mock_logger(i)
    i
  }

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
        File.join(dbl_launcher_options[:web_path],'test123','web'),
        File.join(dbl_launcher_options[:web_path],'clients','client123','web2','web'),
      ].join(':'),
    }
  }

  describe '#uid' do
    it "parse correct uid" do
      expect(method).to eq(1002)
    end
  end
  describe '#gid' do
    it "parse correct gid" do
      expect(method).to eq(1002)
    end
  end
  describe '#listen_uid' do
    it "parse correct uid" do
      expect(method).to eq(1001)
    end
  end
  describe '#listen_gid' do
    it "parse correct gid" do
      expect(method).to eq(1001)
    end
  end

  describe "#spawn_command" do
    before (:example) {
      @list = a_i.spawn_command
    }
    it 'list include spawn_fcgi' do
      expect(@list).to include(dbl_launcher.spawn_cmd_path)
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
    it "not raise error" do
      expect{method}.not_to raise_error
    end
    it "include socket directory" do
      expect(method).to include(File.dirname(default_config['listen']))
    end
    it "include web root directories" do
      # get valid open_base_dirs
      default_config['php_admin_value[open_basedir]'].split(':')[1..-1].each do |dir|
        expect(method).to include(File.dirname(dir))
      end
    end
    it "not include fake directories" do
      dir = default_config['php_admin_value[open_basedir]'].split(':').first
      expect(method).not_to include(dir)
      expect(method).not_to include(File.dirname(dir))
    end
  end
  describe "#php_command" do
    before (:example) {
      @list = method
    }
    it 'list include php cmd' do
      expect(@list).to include(dbl_launcher.php_cmd_path)
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
  describe "#docker_create_options" do
    before(:example) do
      @spawn_list = ['spawn','spawn_args']
      @php_list = ['php','php_args']
      allow(a_i).to receive(:spawn_command).and_return(@spawn_list)
      allow(a_i).to receive(:php_command).and_return(@php_list)
    end
    it "not raise error" do
      expect{method}.not_to raise_error
    end
    it "include volumes if bind_mounts" do
      expect(method.keys).to include('Volumes')
    end
    it "don not include volumes if no bind_mounts" do
      expect(a_i).to receive(:bind_mounts).and_return([])
      expect(method.keys).not_to include('Volumes')
    end
    it 'should map cmds correctly' do
      expect(method).to a_hash_including('Cmd' => (@spawn_list + ['--'] + @php_list))
    end
  end
  let(:dummy_php_spawn) do
      # catch upstream calls
  end
  describe '#container' do
    before (:example) do
      inst_set(:@container,nil)
      dummy_php_spawn
      allow(a_i).to receive(:docker_create_options).and_return({:create => true})
    end
    it 'should use cache if it\'s existing' do
      inst_set(:@container,:cache)
      expect(method).to eq(:cache)
    end
    it 'should build the command correctly' do
      expect(dbl_docker_image).to receive(:create).with({:create => true}).and_return(dbl_docker_container)
      expect(method).to be(dbl_docker_container)
    end
  end
  describe "#start" do
    before (:example) {
      allow(a_i).to receive(:docker_start_options).and_return({:start => true})
      allow(a_i).to receive(:container).and_return(dbl_docker_container)
      allow(dbl_docker_container).to receive(:start)
    }
    it "starts container with options" do
      # container instance
      expect(a_i).to receive(:container).and_return(dbl_docker_container)
      expect(dbl_docker_container).to receive(:start).with({:start => true})
      method
    end
    it 'enables the pool' do
      method
      expect(inst_get(:@enabled)).to eq(true)
    end
  end
  describe "#stop" do
    it "stops existing container" do
      # container instance
      dbl_c_inst = double
      allow(dbl_c_inst).to receive(:delete).with(hash_including(force: true))
      a_i.instance_variable_set(:@container, dbl_c_inst)
      method
      expect(a_i.enabled).to eq(false)
    end
    it "doesn't stop non-existing container" do
      a_i.instance_variable_set(:@container, nil)
      method
      expect(a_i.enabled).to eq(false)
    end
  end
  describe "#container_name" do
    before(:example) do
      a_i.instance_variable_set(:@name, 'myname')
    end
    it '@container_name not set' do
      a_i.instance_variable_set(:@container_name, nil)
      name = method
      expect(name).to a_string_matching(/^myname_[a-f0-9]+$/)
      expect(a_i.instance_variable_get(:@container_name)).to eq (name)
    end
    it '@container_name set' do
      a_i.instance_variable_set(:@container_name, 'myname_cafe')
      name = method
      expect(name).to eq ('myname_cafe')
      expect(a_i.instance_variable_get(:@container_name)).to eq (name)
    end
  end
  describe "#running?" do
    it "container is nil" do
      expect(method).to eq(false)
    end
    it "container is running" do
      expect(dbl_docker_container).to receive(:running?).and_return(true)
      a_i.instance_variable_set(:@container, dbl_docker_container)
      expect(method).to eq(true)
    end
    it "container is not running" do
      expect(dbl_docker_container).to receive(:running?).and_return(false)
      a_i.instance_variable_set(:@container, dbl_docker_container)
      expect(method).to eq(false)
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
        a_i.instance_variable_set(:@enabled, enabled)
        allow(a_i).to receive(:running?).and_return(running)
        if restart
          expect(a_i).to receive(:stop)
          expect(a_i).to receive(:start)
        end
        method
      end
    end
  end
end
