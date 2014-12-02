require 'spec_helper'
require 'php_fpm_docker/docker_container'
require 'php_fpm_docker/docker_image'

module PhpFpmDocker
  describe PhpFpmDocker do
    before {
      begin
        Docker.version
        skip "Enable docker test manually via DOCKER_TEST=1" if ENV['DOCKER_TEST'].nil?
      rescue Excon::Errors::SocketError => e
        skip "Native Docker not available: #{e.message}"
      end
    }
    let(:image) do
      @image_name ||= 'busybox'
      DockerImage.new @image_name
    end
    describe 'docker_integration' do
      before(:example) do
        # Mock log dir
        allow(Application).to receive(:log_path).and_return(Pathname.new(
          File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'tmp', 'rspec.log'))
        ))
      end
      describe DockerImage do
        let(:a_i) do
          image
        end
        context 'find a busybox image' do
          it 'image id should be a string' do
            expect(a_i.id).to be_a String
          end
          it 'image id should be a hex value' do
            expect(a_i.id).to match(/^[a-f0-9]+$/i)
          end
        end
        context 'run commands' do
          it 'ps aux should succeed and output COMMAND' do
            output = a_i.cmd(['ps', 'aux'])
            expect(output[:stdout]).to match(/COMMAND/)
            expect(output[:stderr]).to be_nil
            expect(output[:return_code]).to eq(0)
          end
          it 'uname -a should succeed and output Linux' do
            output = a_i.cmd(['uname', '-a'])
            expect(output[:stdout]).to match(/Linux/)
            expect(output[:stderr]).to be_nil
            expect(output[:return_code]).to eq(0)
          end
          it 'false should fail' do
            output = a_i.cmd(['false'])
            expect(output[:stdout]).to be_nil
            expect(output[:stderr]).to be_nil
            expect(output[:return_code]).to eq(1)
          end
          it 'test stderr output' do
            output = a_i.cmd(['sh','-c','echo test123 >&2'])
            expect(output[:stdout]).to be_nil
            expect(output[:stderr]).to match(/test123/)
            expect(output[:return_code]).to eq(0)
          end
        end
        describe '#detect_output' do
          it 'test detection of php 5.6 image' do
            @image_name = 'simonswine/ispconfig-php-5.6'
            method
            expect(a_i.php_version).to match(/^5\.6/)
            expect(a_i.php_fcgi?).to eq(true)
            expect(a_i.php_path).to eq('/usr/local/bin/php-cgi')
            expect(a_i.spawn_fcgi_path).to eq('/usr/bin/spawn-fcgi')
          end
          it 'test detection of php 4.4 image' do
            @image_name = 'simonswine/ispconfig-php-4.4'
            method
            expect(a_i.php_version).to match(/^4\.4/)
            expect(a_i.php_fcgi?).to eq(true)
            expect(a_i.php_path).to eq('/usr/local/bin/php')
            expect(a_i.spawn_fcgi_path).to eq('/usr/bin/spawn-fcgi')
          end
        end
      end
      describe DockerContainer do
        after(:each) do
          begin
            a_i.delete(force: true)
          rescue RuntimeError
          end
        end
        let(:a_i) do
          described_class.new image
        end
        let(:create) do
          @cmd ||= ['dmesg']
          a_i.create(@cmd)
        end
        let(:fail_not_created) do
          expect{method}.to raise_error(RuntimeError, /no container created/)
        end
        describe '#initialize' do
          it 'image id should be a string' do
            expect(image.id).to be_a String
          end
        end
        describe '#start' do
          it 'should fail without create before' do
            fail_not_created
          end
          it 'should succeed with create before' do
            create
            expect{method}.not_to raise_error
          end
        end
        describe '#status' do
          it 'should fail without created before' do
            fail_not_created
          end
          it 'should report for stopped and never started container' do
            create
            expect(method).to include(running: false, pid: 0)
          end
          it 'should report for started container' do
            @cmd = ['sleep', '5']
            create
            a_i.start
            result = method
            expect(result).to include(running: true)
            expect(result[:pid]).not_to eq(0)
          end
        end
        describe '#running?' do
          it 'false for not created' do
            expect(method).to eq(false)
          end
          it 'false for stopped and never started container' do
            create
            expect(method).to eq(false)
          end
          it 'true for running container' do
            @cmd = ['sleep', '5']
            create
            a_i.start
            expect(method).to eq(true)
          end
        end
      end
    end
  end
end
