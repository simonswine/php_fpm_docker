require 'spec_helper'
require 'php_fpm_docker/docker_container'
require 'php_fpm_docker/docker_image'

describe PhpFpmDocker::DockerContainer do
  before(:example) do
  end
  let (:a_i_only) do
    @image ||= instance_double(
      PhpFpmDocker::DockerImage,
      :id => 'deadbeef',
      :is_a? => true,
    )
    allow(@image).to receive(:is_a?).and_return(true)
    described_class.new(@image)
  end
  let (:a_i) do
    mock_logger(a_i_only)
    a_i_only
  end
  let (:dbl_image) do
  end
  describe '.cmd' do
    it 'forwads to new container and creates it' do
      c = instance_double(PhpFpmDocker::DockerContainer)
      expect(PhpFpmDocker::DockerContainer).to receive(:new).and_return(c)
      expect(c).to receive(:create).with(:args)
      expect(c).to receive(:output).and_return(:output)
      expect(described_class.cmd(:image,:args)).to eq(:output)
    end
  end
  describe '#initialize' do
    it 'should set @image_name' do
      expect(inst_get(:@image_name)).to eq(@image_name)
    end
    it 'should test for object class' do
      i=instance_double(PhpFpmDocker::DockerImage)
      expect(i).to receive(:is_a?).and_return(false)
      expect{method i}.to raise_error(ArgumentError)
    end
  end
  describe '#options' do
    it 'should include the right image id' do
      expect(method).to include('Image' => @image.id)
    end
  end
  describe '#output' do
    after(:example) do
      allow(a_i).to receive(:method_missing) do |sym, *args, &block|
        if sym == :attach
          [@stdout, @stderr]
        elsif sym == :wait
          {'StatusCode' => @return_code}
        elsif sym == :delete
          expect(args.first).to include(force: true)
          nil
        elsif sym == :start
          nil
        else
          fail "unexpected method #{sym}"
        end
      end
      expect(method).to eq(@result)
    end
    it 'should manage missing stderr' do
      @stdout = ["stdout1\n","stdout2\n"]
      @stderr = []
      @return_code = 666
      @result = {
        :stderr => nil,
        :stdout => "stdout1\nstdout2\n",
        :return_code => @return_code
      }
    end
    it 'should manage missing stdout' do
      @stderr = ["stderr1\n","stderr2\n"]
      @stdout = []
      @return_code = 555
      @result = {
        :stderr => "stderr1\nstderr2\n",
        :stdout => nil,
        :return_code => @return_code
      }
    end
  end
  describe '#method_missing' do
    before(:example) do
      @cont = instance_double(Docker::Container)
      allow(a_i).to receive(:container).and_return(@cont)
    end
    context 'forward methods' do
      [:start, :stop, :delete, :wait, :logs, :attach].each do |method|
        it "should forward :#{method}" do
          expect(@cont).to receive(method).with(:args)
          a_i.send(method, :args)
        end
      end
      it "should not forward :not_existing_method" do
        expect{a_i.send(:not_existing_method, :args)}.to raise_error(NoMethodError)
      end
    end
  end
  describe '#create' do
    before(:example) do
      a_i
      @output = {
        'Image' => @image.id,
        'Cmd' => ['test','me'],
      }
      @input = { 'Cmd' => deep_clone(@output['Cmd']) }
      @opts = {}
    end
    context 'creates container' do
      after(:example) do
        expect(Docker::Container).to receive(:create).with(deep_clone @output).and_return(:container)
        expect(method(@input)).to eq(:container)
      end
      it 'creates container and appends options' do
        @input['name'] = 'name1'
        @output['name'] = 'name1'
      end
      it 'creates container and appends options' do
        @input['name'] = 'name1'
        @output['name'] = 'name1'
      end
      it 'creates container with array argument' do
        @input = @input['Cmd']
      end
      it 'creates container with hash argument' do
      end
      it 'creates container and string only cmd array' do
        @input['Cmd'] << 100
        @output['Cmd'] << '100'
      end
      it 'overrides default options' do
        @input['Image'] = 'dead'
        @output['Image'] = 'dead'
      end 
      it 'logs container creation' do
        expect(dbl_logger).to receive(:debug) do |&block|
          expect(block.call).to match(/created container/)
        end
      end
    end
    it 'fail if nil input' do
      @input = nil
      expect{method(@input)}.to raise_error(ArgumentError, /has to be a hash/)
    end
    it 'fail if nil cmd' do
      @input['Cmd'] = nil
      expect{method(@input)}.to raise_error(ArgumentError, /no array/)
    end
  end
  describe '#to_s' do
    before(:example) do
      expect(a_i).to receive(:id).and_return(:id1)
      d = instance_double('DockerImage', :name => :name1)
      inst_set(:@image, d)
    end
    after(:example) do
      result = method
      expect(result).to be_a(String)
      expect(result).to match(/id1/)
      expect(result).to match(/name1/)
    end
    it 'should return string repr' do
    end
  end
  describe '#id' do
    before(:example) do
      @dbl_container = instance_double(Docker::Container)
    end
    after(:example) do
      expect(a_i).to receive(:container).and_return(@dbl_container)
      expect(method).to eq(@result)
    end
    it 'should return id' do
      allow(@dbl_container).to receive(:id).and_return(:id1)
      @result = :id1
    end
    it 'should handle errors' do
      allow(@dbl_container).to receive(:id).and_raise(RuntimeError,:test_error)
      @result = 'unknown'
    end
  end
end
