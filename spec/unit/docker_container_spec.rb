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
  describe '#create' do
    before(:example) do
      a_i
      @output = {
        'Image' => @image.id,
        'Cmd' => ['test','me'],
      }
      @input = deep_clone @output['Cmd']
      @opts = {}
    end
    context 'creates container' do
      after(:example) do
        expect(Docker::Container).to receive(:create).with(deep_clone @output).and_return(:container)
        expect(method(@input,@opts)).to eq(:container)
      end
      it 'creates container' do
      end
      it 'creates container and appends options' do
        @opts['name'] = 'name1'
        @output['name'] = 'name1'
      end
      it 'creates container and string only cmd array' do
        @output['Cmd'] << '100'
        @input << 100
      end
      it 'overrides default options' do
        @opts['Image'] = 'dead'
        @output['Image'] = 'dead'
      end
    end
    it 'fail if nil cmd' do
      @input = nil
      @fail = true
      expect{method(@input,@opts)}.to raise_error(ArgumentError, /no array/)
    end
  end
end
