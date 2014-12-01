require 'spec_helper'
require 'php_fpm_docker/application'

describe PhpFpmDocker::Application do
  before(:example) {
    @dbl_fileutils = class_double('FileUtils').as_stubbed_const()
    allow(@dbl_fileutils).to receive(:mkdir_p)
  }

  let (:a_i){
    i=described_class.new
    mock_logger(i)
    i
  }
  let (:pid_default) {
    1234
  }

  describe '.log_path' do
    let(:method) do
      described_class.log_path
    end
    it 'should show class inst variable' do
      described_class.instance_variable_set(:@log_path, Pathname.new('/tmp/test/test.log'))
      expect(method).to eq(Pathname.new '/tmp/test/test.log')
    end
    it 'should append wrapper.log to default dir' do
      described_class.instance_variable_set(:@log_path, nil)
      expect(described_class).to receive(:log_dir_path).and_return(Pathname.new '/tmp/test')
      expect(method).to eq(Pathname.new '/tmp/test/wrapper.log')
    end
  end

  describe '.log_path=' do
    let(:method) do
      described_class.log_path = @args.dup
    end
    it 'should take a String arg' do
      @args = '/tmp/test/test.log'
      method
      log_path = described_class.instance_variable_get(:@log_path)
      expect(log_path.to_s).to eq(@args)
      expect(log_path).to be_a(Pathname)
    end
    it 'should take a Pathname arg' do
      @args = Pathname.new '/tmp/test/test.log'
      method
      log_path = described_class.instance_variable_get(:@log_path)
      expect(log_path).to eq(@args)
    end
  end

  describe '.log_dir_path' do
    let(:method) do
      described_class.log_dir_path
    end
    it 'should return a pathname' do 
      expect(method).to be_a(Pathname)
    end
  end

  describe '#initialize' do
    it "not raise error" do
      expect{a_i}.not_to raise_error
    end
  end
  describe '#help' do
    it "return help" do
      expect(a_i).to receive(:allowed_methods).and_return([:valid])
      expect{method}.to output(/valid/).to_stderr
    end
  end
  describe '#run' do
    let (:method) {
      a_i.instance_eval{ run }
    }
    before (:example) do
      a_i.instance_variable_set(:@php_name,'php_name')
      @argv = []
      stub_const('ARGV', @argv)
    end
    it "correct arguments" do
      expect(a_i).to receive(:parse_arguments).with(@argv).and_return(:valid)
      expect(a_i).to receive(:send).with(:valid).and_return(123)
      expect(a_i).to receive(:exit).with(123)
      expect{method}.not_to raise_error
    end
    it "incorrect arguments" do
      allow(dbl_logger).to receive(:warn).with('php_name')
      expect(a_i).to receive(:parse_arguments).with(@argv).and_raise(RuntimeError, 'wrong')
      expect(a_i).to receive(:help)
      expect(a_i).to receive(:exit).with(3)
      expect{method}.not_to raise_error
    end
  end
  describe '#parse_arguments' do
    let (:method) {
      a_i.instance_exec(@args) {|x| parse_arguments(x)}
    }
    let (:valid_args) {
      a_i.instance_variable_set(:@php_name,'php_name')
      expect(a_i).to receive(:allowed_methods).and_return([:valid])
    }
    it 'fails without arguments' do
      @args = []
      expect{method}.to raise_error(/no argument/)
    end
    it "args=['install']" do
      @args = ['install']
      expect(method).to eq(:install)
    end
    it "args=['name','valid']" do
      valid_args
      @args = ['name','valid']
      expect(dbl_logger).to receive(:info)
      expect(method).to eq(:valid)
      expect(a_i.instance_variable_get(:@php_name)).to eq('name')
    end
    it "args=['name','invalid']" do
      valid_args
      @args = ['name','invalid']
      expect{method}.to raise_error(/unknown method/)
    end
    it "args=['name']" do
      @args = ['name']
      expect{method}.to raise_error(/wrong argument count/)
    end
  end
  describe '#allowed_methods' do
    let (:method) {
      a_i.instance_eval{ allowed_methods }
    }
    it "have exactly the commands" do
      expect(method).to contain_exactly(:start, :stop, :reload, :restart, :status)
    end
  end
  describe '#pid' do
    before (:example) do
      @file = Tempfile.new('pid_file')
      allow(a_i).to receive(:pid_path).and_return(Pathname.new(@file.path))
    end
    it 'return pid from file if exists and int' do
      @file.write(pid_default.to_s)
      @file.flush
      expect(method).to eq(pid_default)
    end
    it 'return nil without pid file' do
      @file.delete
      expect(method).to eq(nil)
    end
    it 'return nil pid from file if exists and no int' do
      @file.write("fuckyeah!")
      @file.flush
      expect(method).to eq(nil)
    end
  end
  describe '#pid=' do
    before(:example) do
      @file=Tempfile.new('foo')
      @file.write(1234)
      @file.flush
    end
    context 'argument pid is 456' do
      let (:method) {
        a_i.instance_exec(nil) {|x| self.pid=456 }
      }
      after(:example) do
        allow(a_i).to receive(:pid_path).and_return(Pathname.new(@file.path))
        method
        expect(open(@file.path).read.strip.to_i).to eq(456)
      end
      it 'pid file exists before' do
      end
      it 'pid file not existing' do
        File.unlink @file.path
      end
    end
    context 'argument pid is nil' do
      let (:method) {
        a_i.instance_exec(nil) {|x| self.pid=x }
      }
      it 'pid file will removed if exists' do
        allow(a_i).to receive(:pid_path).and_return(@file.path)
        method
        expect(File.exist?(@file.path)).to eq(false)
      end
      it 'pid file not existing' do
        path = @file.path
        @file.delete
        expect(dbl_logger).to receive(:debug).with(/No pid file found/)
        allow(a_i).to receive(:pid_path).and_return(path)
        method
      end
    end
  end
  describe '#running?' do
    let (:method) {
      a_i.instance_eval{ running? }
    }
    it 'return false if no pid' do
      expect(a_i).to receive(:pid).and_return(nil)
      expect(method).to be(false)
    end
    it 'return true if pid exists' do
      pid = 1234
      allow(a_i).to receive(:pid).and_return(pid)
      # mock process
      dbl_process = class_double('Process').as_stubbed_const()
      allow(dbl_process).to receive(:getpgid).with(pid)
      expect(method).to be(true)
    end
    it 'return false for non existing pid' do
      pid = 1234
      allow(a_i).to receive(:pid).and_return(pid)
      # mock process
      dbl_process = class_double('Process').as_stubbed_const()
      allow(dbl_process).to receive(:getpgid).and_raise(Errno::ESRCH)
      expect(method).to be(false)
    end
  end
end
