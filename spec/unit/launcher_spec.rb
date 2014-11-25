require 'spec_helper'
require 'php_fpm_docker/launcher'

describe PhpFpmDocker::Launcher do
  before(:example) {
    # Logger
    @dbl_logger_instance = double
    [:debug,:error,:warn,:info,:fatal].each do |loglevel|
      allow(@dbl_logger_instance).to receive(loglevel)
    end
    @dbl_logger = class_double('Logger').as_stubbed_const()
    allow(@dbl_logger).to receive(:new).and_return(@dbl_logger_instance)

    @dbl_pool = class_double('PhpFpmDocker::Pool').as_stubbed_const()

    # Fileutils
    @dbl_fileutils = class_double('FileUtils').as_stubbed_const()
    allow(@dbl_fileutils).to receive(:mkdir_p)
  }
  let (:a_i){
    allow_any_instance_of(described_class).to receive(:test)
    described_class.new(@name ||=  'launcher1')
  }
  let (:a_c){
    described_class
  }
  describe '#initialize' do
    let (:method){
      expect_any_instance_of(described_class).to receive(:test)
      described_class.new(@name ||=  'launcher1')
    }
    it 'should not raise error' do
      expect{method}.not_to raise_error
    end
  end
  describe '#test' do
    before(:example) {
      expect_any_instance_of(described_class).to receive(:test).and_call_original
      @downstream_methods = [:test_docker_image,:test_directories, :parse_config]
    }
    let (:method){
      described_class.new(@name ||=  'launcher1')
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
      allow(@dbl_pool).to receive(:new).and_return(:object)
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
      expect(@dbl_pool).to receive(:new) do |args|
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
      expect(@dbl_pool).not_to receive(:new)
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
      allow(a_i).to receive(:pools_from_config).and_return({})
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
      expect(a_i).to receive(:pools_from_config).once.and_return(test)
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
  describe '#check_pools' do
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
      expect(@dbl_logger_instance).not_to receive(:warn)
      templates
      method_with_args
    end
    it 'all pools error' do
      @method = :start
      error = 'servus der error'
      expect(@dbl_logger_instance).to receive(:warn) do |pool,&block|
        expect(block.call).to match(/#{error}/)
      end.twice
      templates
      @objects.each do |obj|
        expect(obj).to receive(@method).and_raise(RuntimeError, error)
      end
      method(@hash, @hash.keys, @method)
    end
  end
end
