require 'spec_helper'
require 'php_fpm_docker/application'

describe PhpFpmDocker::Application do
  before(:example) {
    @dbl_logger_instance = double
    @dbl_logger = class_double('Logger').as_stubbed_const()
    allow(@dbl_logger).to receive(:new).and_return(@dbl_logger_instance)

    @dbl_fileutils = class_double('FileUtils').as_stubbed_const()
    allow(@dbl_fileutils).to receive(:mkdir_p)
  }

  let (:a_i){
    described_class.new
  }
  let (:a_c){
    described_class
  }
  let (:pid_default) {
    1234
  }

  describe '#initialize' do
    it "not raise error" do
      expect{a_i}.not_to raise_error
    end
  end
  describe '#help' do
    let (:method) {
      a_i.instance_eval{ help }
    }
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
      allow(@dbl_logger_instance).to receive(:warn).with('php_name')
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
      expect(@dbl_logger_instance).to receive(:info)
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
    let (:method) {
      a_i.instance_eval{ pid }
    }
    let (:file) {
      Tempfile.new('foo')
    }
    it 'return pid from file if exists and int' do
      file.write(pid_default.to_s)
      file.flush
      allow(a_i).to receive(:pid_file).and_return(file.path)
      expect(method).to eq(pid_default)
    end
    it 'return nil without pid file' do
      allow(a_i).to receive(:pid_file).and_return('/tmp/not/existing')
      expect(method).to eq(nil)
    end
    it 'return nil pid from file if exists and no int' do
      file.write("fuckyeah!")
      file.flush
      allow(a_i).to receive(:pid_file).and_return(file.path)
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
        allow(a_i).to receive(:pid_file).and_return(@file.path)
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
        allow(a_i).to receive(:pid_file).and_return(@file.path)
        method
        expect(File.exist?(@file.path)).to eq(false)
      end
      it 'pid file not existing' do
        path = @file.path
        @file.delete
        expect(@dbl_logger_instance).to receive(:debug).with(/No pid file found/)
        allow(a_i).to receive(:pid_file).and_return(path)
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
