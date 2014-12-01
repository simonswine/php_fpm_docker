require 'spec_helper'
require 'php_fpm_docker/launcher'

describe PhpFpmDocker::Launcher do
  before(:example) {
    @dbl_c_pool = class_double('PhpFpmDocker::Pool').as_stubbed_const()

    # Mock Application
    @dbl_c_application = class_double('PhpFpmDocker::Application').as_stubbed_const()
    allow(@dbl_c_application).to receive(:log_dir_path).and_return(Pathname.new '/tmp/test123/')
    allow(@dbl_c_application).to receive(:log_path=)

    # Fileutils
    @orig_fileutils = FileUtils
    @dbl_fileutils = class_double('FileUtils').as_stubbed_const()
    allow(@dbl_fileutils).to receive(:mkdir_p)
  }
  let (:a_i_only) {
    @dbl_app = instance_double('PhpFpmDocker::Application')
    described_class.new(@name ||=  'launcher1', @dbl_app)
  }
  let (:a_i){
    allow(a_i_only).to receive(:test)
    mock_logger(a_i_only)
    a_i_only
  }
  let (:a_c){
    described_class
  }
  xdescribe '#initialize' do
    let (:method){
      expect_any_instance_of(described_class).to receive(:test)
      a_i_only
    }
    it 'should not raise error' do
      expect{method}.not_to raise_error
    end
  end
  xdescribe '#test' do
    before(:example) {
      expect_any_instance_of(described_class).to receive(:test).and_call_original
      @downstream_methods = [:test_directories]
    }
    let (:method){
      a_i_only
    }
    it 'should call down stream functions' do
      @downstream_methods.each do |m|
        expect_any_instance_of(described_class).to receive(m)
      end
      method
    end
    it 'should exit on runtime errors' do
      @downstream_methods.each do |m|
        allow_any_instance_of(described_class).to receive(m).and_raise(RuntimeError,"error")
      end
      expect_any_instance_of(described_class).to receive(:exit).with(1)
      method
    end
  end
  describe '#run' do
    before (:example) {
      @pid = 12345
      allow(a_i).to receive(:start_pools)
      allow(a_i).to receive(:fork).and_return(@pid)
    }
    it 'should start pools' do
      # start pools
      expect(a_i).to receive(:start_pools)
      method
    end
    it 'should fork and detach daemon' do
      expect(a_i).to receive(:fork).once do |&block|
        expect(a_i).to receive(:fork_run).once
        block.call
      end.and_return(@pid)
      expect(Process).to receive(:detach).with(@pid)
      method
    end
    it 'shoud return pid' do
      expect(method).to eq(@pid)
    end
  end
  describe '#fork_run' do
    before (:example) {
      allow(Signal).to receive(:trap)
      allow(Kernel).to receive(:loop)
    }
    it 'should handle signal USR1' do
      expect(Signal).to receive(:trap).with('USR1').once do |&block|
        expect(a_i).to receive(:reload_pools)
        block.call
      end
      method
    end
    it 'should handle signal TERM' do
      expect(Signal).to receive(:trap).with('TERM').once do |&block|
        expect(a_i).to receive(:stop_pools)
        expect(a_i).to receive(:exit).with(0)
        block.call
      end
      method
    end
    it 'should loop and check pools' do
      expect(Kernel).to receive(:loop) do |&block|
        expect(a_i).to receive(:sleep).with(1)
        expect(a_i).to receive(:check_pools)
        block.call
      end
      method
    end
  end
  describe '#check_pools'
  describe '#start_pools' do
    before (:example) {
      allow(a_i).to receive(:reload_pools)
    }
    it 'should reset @pools' do
      a_i.instance_variable_set(:@pools, {:lala => :test})
      method
      expect(a_i.instance_variable_get(:@pools)).to eq({})
    end
    it 'should trigger reload pools' do
      expect(a_i).to receive(:reload_pools)
      method
    end
  end
  describe '#stop_pools' do
    before (:example) {
      allow(a_i).to receive(:reload_pools)
    }
    it 'should trigger reload pools' do
      expect(a_i).to receive(:reload_pools)
      method
    end
  end
  describe '#create_missing_pool_objects' do
    let (:set) {
      inst_set(:@pools,@pools)
      inst_set(:@pools_old,@pools_old)
    }
    let (:compare) {
      expect(inst_get(:@pools)).to match(@pools)
      expect(inst_get(:@pools_old)).to match(@pools_old)
    }
    let (:method1) {
      set
      method
      compare
    }
    it 'should not fail with nil values' do
      @pools = nil
      @pools_old = nil
      method1
    end
    it 'should not fail with empty hashes' do
      @pools = {}
      @pools_old = {}
      method1
    end
    it 'should copy objects correctly' do
      @pools = { :hash1 => {}, :hash3 => {}}
      @pools_old = {
        :hash1 => {:object => :object1},
        :hash2 => {:object => :object2},
        :hash3 => {:object => :object3}
      }
      set
      method
      @pools = {
        :hash1 => {:object => :object1},
        :hash3 => {:object => :object3}
      }
      compare
    end
  end
  describe '#move_existing_pool_objects' do
    let (:set) {
      inst_set(:@pools,@pools)
    }
    let (:compare) {
      expect(a_i.instance_variable_get(:@pools)).to match(@result)
    }
    let (:set_method_compare) {
      set
      method
      compare
    }
    before(:example) {
      allow(@dbl_c_pool).to receive(:new).and_return(:object)
    }
    it 'should not fail with nil value' do
      @pools = nil
      @result = nil
      set_method_compare
    end
    it 'should not fail with empty hash' do
      @pools = {}
      @result = {}
      set_method_compare
    end
    it 'should create missing objects' do
      @pools = {
        :hash1 => {:object => :object1},
        :hash2 => {:name => :name2, :config => :config2},
        :hash3 => {:object => :object3}
      }
      expect(@dbl_c_pool).to receive(:new) do |args|
        expect(args).to have_key(:launcher)
        expect(args).to include(@pools[:hash2])
      end.and_return(:object2)
      set
      method
      @result = @pools
      @result[:hash2][:object] = :object2
      compare
    end
    it 'should not recreate existing objects' do
      @result = @pools = {
        :hash1 => {:object => :object1},
        :hash2 => {:object => :object2},
      }
      expect(@dbl_c_pool).not_to receive(:new)
      set_method_compare
    end
  end
  describe '#reload_pools' do
    before(:example) {
      [
        :move_existing_pool_objects,
        :pools_action,
        :create_missing_pool_objects,
      ].each {|m| allow(a_i).to receive(m)}
      allow(a_i).to receive(:pools_config).and_return({})
      inst_set(:@pools, {})
      inst_set(:@pools_old, {})
    }
    let(:check_set_op){
      expect(a_i).to receive(:pools_action) do |p,p_h,action|
        next if action != @method

        source = {
          :stop  => :@pools_old,
          :start => :@pools,
        }
        expect(p).to be(inst_get(source[@method]))
        expect(p_h).to eq(@result)

      end.at_least(:once)
      inst_set(:@pools, {
        :hash1 => {:object => :object1},
        :hash2 => {:object => :object2},
      })
      method({
        :hash1 => {:object => :object1},
        :hash3 => {:object => :object3},
        :hash4 => {:object => :object4},
      })
    }
    it 'should read pool from config with arg=nil' do
      test = {:me => :myself}
      expect(a_i).to receive(:pools_config).once.and_return(test)
      method
      expect(inst_get(:@pools)).to eq(test)
    end
    it 'should read pool from args' do
      test = {:me => :myself}
      method(test)
      expect(inst_get(:@pools)).to eq(test)
    end
    it 'should call :create_missing_pool_objects' do
      expect(a_i).to receive(:create_missing_pool_objects).once
      method
    end
    it 'should call :move_existing_pool_objects' do
      expect(a_i).to receive(:move_existing_pool_objects).once
      method
    end
    it 'should move @pools to @pools_old' do
      pools_old = inst_get(:@pools)
      method
      expect(inst_get(:@pools_old)).to be(pools_old)
    end
    it 'should stop unneeded pools' do
      @method = :stop
      @result = [:hash2]
      check_set_op
    end
    it 'should start the new pools' do
      @method = :start
      @result = [:hash3, :hash4]
      check_set_op
    end
  end
  describe '#check_pools_n' do
    it 'forwards to pools_action' do
      hash = {
        :hash1 => { :name => :map1},
        :hash2 => { :name => :map2},
      }
      inst_set :@pools, hash
      args = [hash, hash.keys, :check]
      expect(a_i).to receive(:pools_action) do |*my_args|
        expect(my_args).to eq(args)
      end.once
      method
    end
  end
  describe '#pools_action' do
    let!(:templates) {
      @objects = [ double('object1'), double('object2') ]
      @hash = {
        :hash1 => { :name => :map1, :object => @objects[0]},
        :hash2 => { :name => :map2, :object => @objects[1]},
      }
    }
    let(:method_with_args){
      @objects.each do |obj|
        expect(obj).to receive(@method)
      end
      method(@hash, @hash.keys, @method)
    }
    it 'all pools run without error' do
      @method = :start
      expect(dbl_logger).not_to receive(:warn)
      templates
      method_with_args
    end
    it 'all pools error' do
      @method = :start
      error = 'servus der error'
      expect(dbl_logger).to receive(:warn) do |pool,&block|
        expect(block.call).to match(/#{error}/)
      end.twice
      templates
      @objects.each do |obj|
        expect(obj).to receive(@method).and_raise(RuntimeError, error)
      end
      method(@hash, @hash.keys, @method)
    end
  end
  describe '#test_directories' do
    before(:example){
      @dirs = {}
      [ :config_dir_path, :pools_dir_path ].each do |m|
        @dirs[m] = dir = Dir.mktmpdir(m.to_s)
        allow(a_i).to receive(m).and_return(Pathname.new dir)
      end
    }
    after(:example) {
      @dirs.each do |key,dir|
        @orig_fileutils.rm_rf(dir) if File.exist? dir
      end
    }
    it 'succeeds if all dirs exist' do
      method
    end
    it 'fails if config_dir is missing' do
      @orig_fileutils.rm_rf(@dirs[:config_dir_path])
      expect{method}.to raise_error(/not found/)
    end
    it 'fails if pools_dir is missing' do
      @orig_fileutils.rm_rf(@dirs[:pools_dir_path])
      expect{method}.to raise_error(/not found/)
    end
  end
  describe '#bind_mounts' do
    before(:example){
      @bind_mounts_apps = ['app1', 'app2', 'dup1', 'dup2']
      @bind_mounts_mine = ['mine1', ' mine2 ', 'dup1 ', 'dup2' ]
    }
    let(:set_mine){
      allow(a_i).to receive(:config).and_return({'global' => {'bind_mounts' => @bind_mounts_mine.join(',')}})
    }
    let(:set_apps){
      expect(@dbl_app).to receive(:bind_mounts).and_return(@bind_mounts_apps.dup)
    }
    after(:example) {
    }
    it 'returns application\'s mounts' do
      set_mine
      set_apps
      expect(method).to include(*@bind_mounts_apps)
    end
    it 'removes white spaces from mine' do
      set_mine
      set_apps
      mounts = @bind_mounts_mine.map {|m| m.strip}
      expect(method).to include(*mounts)
    end
    it 'removes duplicates' do
      set_mine
      set_apps
      result = method
      expect(result).to contain_exactly(*result.uniq)
    end
    it 'does not fail if not configured' do
      allow(a_i).to receive(:config).and_return({})
      set_apps
      expect(method).to contain_exactly(*@bind_mounts_apps)
    end
  end
  describe 'join functions' do
    before(:example){
      a_i
      expect(@dbl_app).to receive(:config_dir_path).and_return(Pathname.new('/tmp/etc/php_fpm_config')).once
    }
    [
      [:config_dir_path, /#{@name}$/],
      [:config_path, /config\.ini$/],
      [:pools_dir_path, /pools\.d$/],
    ].each do |m, re|
      describe "##{m.to_s}" do
        it 'returns joined pathname' do
          result = method
          expect(result).to be_a(Pathname)
          expect(result.to_s).to match(re)
        end
      end
    end
  end
  describe '#web_path' do
    before(:example) {
      @app_path = Pathname.new '/tmp/app'
      @launcher_path = Pathname.new '/tmp/laun'
      @result = @app_path.to_s
      a_i
      allow(@dbl_app).to receive(:web_path).and_return(@app_path)
    }
    after(:example) {
      allow(a_i).to receive(:config).and_return(@ini_file)
      result = method
      expect(result).to be_a(Pathname)
      expect(result.to_s).to eq(@result)
    }
    it 'returns launcher config if set' do
      @ini_file = { :main => {'web_path' => @launcher_path.to_s}}
      @result = @launcher_path.to_s
    end
    it 'return app config if empty string' do
      @ini_file = { :main => {'web_path' => ''}}
    end
    it 'return app config if no inifile' do
      @ini_file = nil
    end
    it 'return app config if nil value' do
      @ini_file = { :main => {}}
    end
  end
end
