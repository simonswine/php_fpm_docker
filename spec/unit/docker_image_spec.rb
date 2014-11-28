require 'spec_helper'
require 'php_fpm_docker/docker_image'
require 'php_fpm_docker/docker_container'

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
  let (:execon_error) do
      msg = double
      @error ||= 'error0815'
      allow(msg).to receive(:message).and_return(@error)
      allow(msg).to receive(:backtrace)
      msg
  end
  let (:dbl_image) do
    instance_double(Docker::Image, id: :id1)
  end
  describe 'self.available?' do
    it 'should be true if docker is available' do
      expect(Docker).to receive(:version)
      expect(described_class.available?).to eq(true)
    end
    it 'should be false if docker is not available' do
      expect(Docker).to receive(:version).and_raise(Excon::Errors::SocketError, execon_error)
      expect(described_class.available?).to eq(false)
    end
  end
  describe '#initialize' do
    it 'should set @name' do
      expect(inst_get(:@name)).to eq(@name)
    end
  end
  describe '#id' do
    it 'should get image id' do
      expect(a_i).to receive(:image).and_return(double(id: :id1))
      expect(method).to eq(:id1)
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
    it 'should call and return docker image' do
      a_i
      expect(Docker::Image).to upstream.with(@name)
      expect(@dbl_logger).to receive(:info) do |&block|
        expect(block.call).to match(/fetched docker/)
      end
      expect(method).to eq(dbl_image)
    end
    it 'should catch not found' do
      a_i
      expect(Docker::Image).to upstream.and_raise(Docker::Error::NotFoundError)
      expect{method}.to raise_error(RuntimeError,/not found/)
    end
    it 'should catch connection issues' do
      a_i
      expect(Docker::Image).to upstream.and_raise(Excon::Errors::SocketError, execon_error)
      expect{method}.to raise_error(RuntimeError, /#{@error}/)
      method
    end
  end
  describe '#cmd' do
    it 'forwards commands to DockerContainer' do
      expect(PhpFpmDocker::DockerContainer).to receive(:cmd) do |*args|
        expect(args[0]).to be(a_i)
        expect(args[1]).to eq(:arg1)
      end
      method(:arg1)
    end
  end
  describe '#to_s' do
    it 'returns string representation' do
      expect(method).to be_a(String)
    end
  end
  describe '#detect_output' do
    it 'should return cache if exists' do
      inst_set(:@detect_output, :cache)
      expect(a_i).not_to receive(:detect_fetch)
      expect(method).to eq(:cache)
    end
    it 'should gather and cache' do
      inst_set(:@detect_output, nil)
      expect(a_i).to receive(:detect_fetch).and_return(:upstream)
      expect(method).to eq(:upstream)
    end
  end
  context 'path detection' do
    before(:example) do
      allow(a_i).to receive(:detect_output).and_return([
        'spawn_fcgi_path=/spawn_fcgi_path',
        'php_path=/php_path',
      ])
    end
    describe '#spawn_fcgi_path' do
      it 'return correct answer if found' do
        expect(method).to eq('/spawn_fcgi_path')
      end
    end
    describe '#php_path' do
      it 'return correct answer if found' do
        expect(method).to eq('/php_path')
      end
    end
    describe '#detect_find_path' do
      it 'return nil if not found' do
        expect(method(:missing)).to eq(nil)
      end
    end
  end
  context 'php version detection' do
    after(:example) do
      allow(a_i).to receive(:detect_output).and_return([
        '',
        '',
        @input,
      ])
      expect(method).to eq(@output)
    end
    [
      [
        'PHP 5.5.9-1ubuntu4.5 (cli) (built: Oct 29 2014 11:59:10)',
        false,
        '5.5.9-1ubuntu4.5',
      ],
      [
        'PHP 5.5.9-1ubuntu4.5 (cgi-fcgi) (built: Oct 29 2014 12:00:14)',
        true,
        '5.5.9-1ubuntu4.5',
      ],
      [
        'PHP 4.4.9 (cgi-fcgi) (built: Sep 20 2014 08:51:50)',
        true,
        '4.4.9',
      ],
      [
        'PHP 5.6.3 (cli) (built: Nov 17 2014 14:14:14)',
        false,
        '5.6.3',
      ],
      [
        'PHP 5.6.3 (cgi-fcgi) (built: Nov 17 2014 14:14:17)',
        true,
        '5.6.3',
      ],
      [
        'Garbage',
        false,
        nil,
      ],
    ].each do |input,output_fcgi, output_version|
      describe '#php_version' do
        it "should parse '#{input}'" do
          @input = input
          @output = output_version
        end
      end
      describe '#php_fcgi?' do
        it "should parse '#{input}'" do
          @input = input
          @output = output_fcgi
        end
      end
    end
  end
  describe '#detect_cmd' do
    before(:example) do
      expect(a_i).to receive(:detect_binary_shell) do |*args|
        ":#{args.first.to_s}"
      end.at_least(:twice)
    end
    it 'should contain php' do
      expect(method).to match(/:php/)
    end
    it 'should contain spawn_fcgi' do
      expect(method).to match(/:spawn_fcgi/)
    end
    it 'should contain version test' do
      expect(method).to match(/-v/)
    end
  end
  describe '#detect_binary_shell' do
    it 'should return with multiple elements in list' do
      expect(method(:cmd,['pos1','pos2','pos3'])).to include(
        match(/CMD_PATH=/),
        match(/which pos1/),
        match(/which pos2/),
        match(/which pos3/),
      )
    end
    it 'should return with one element in list' do
      expect(method(:cmd,['pos1'])).to include(
        match(/CMD_PATH=/),
        match(/which pos1/),
      )
    end
  end
end
