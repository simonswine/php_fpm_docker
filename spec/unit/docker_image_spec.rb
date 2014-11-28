require 'spec_helper'
require 'php_fpm_docker/docker_image'

describe PhpFpmDocker::DockerImage do
  before(:example) do
  end
  let (:a_i_only) do
    described_class.new(@name ||= 'image/name')
  end
  let (:a_i) do
    mock_logger(a_i_only)
    a_i_only
  end
  let (:dbl_image) do
    instance_double(Docker::Image)
  end
  describe '#initialize' do
    it 'should set @name' do
      expect(inst_get(:@name)).to eq(@name)
    end
  end
  describe '#image' do
    let(:upstream) do
      receive(:fetch_image)
    end
    it 'should use cached if existing' do
      inst_set(:@image, :image_cache)
      expect(a_i).not_to upstream
      expect(method).to eq(:image_cache)
    end
    it 'should call and store in cache' do
      inst_set(:@image, nil)
      expect(a_i).to upstream.and_return(:image_new)
      expect(method).to eq(:image_new)
      expect(inst_get(:@image)).to eq(:image_new)
    end
  end
  describe '#fetch_image' do
    before(:example) do
      allow(Docker::Image).to upstream
    end
    let(:upstream) do
      receive(:get).and_return(dbl_image)
    end
    it 'should call and docker image' do
      a_i
      expect(Docker::Image).to upstream.with(@name)
      expect(method).to eq(dbl_image)
    end
    it 'should catch not found' do
      a_i
      expect(Docker::Image).to upstream.and_raise(Docker::Error::NotFoundError)
      expect{method}.to raise_error(RuntimeError,/not found/)
    end
    it 'should catch connection issues' do
      a_i
      msg = double
      error = 'error0815'
      allow(msg).to receive(:message).and_return(error)
      allow(msg).to receive(:backtrace)
      expect(Docker::Image).to upstream.and_raise(Excon::Errors::SocketError, msg)
      expect{method}.to raise_error(RuntimeError, /#{error}/)
      method
    end
  end
end
