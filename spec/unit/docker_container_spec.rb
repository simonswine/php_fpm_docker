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
end
