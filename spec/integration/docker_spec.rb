require 'spec_helper'
require 'php_fpm_docker/docker_container'
require 'php_fpm_docker/docker_image'

module PhpFpmDocker
  describe PhpFpmDocker do
    let(:image) do
      @image_name ||= 'busybox'
      DockerImage.new 'busybox'
    end
    describe 'docker_integration' do
      describe DockerImage do
        context 'find a busybox image' do
          it 'image id should be a string' do
            expect(image.id).to be_a String
          end
          it 'image id should be a hex value' do
            expect(image.id).to match(/^[a-f0-9]+$/i)
          end
        end
        context 'run commands' do
          for i in 0..100
            it 'ps aux should succeed and output COMMAND' do
              output = image.cmd(['ps', 'aux'])
              expect(output[:stdout]).to match(/COMMAND/)
              expect(output[:stderr]).to be_nil
              expect(output[:return_code]).to eq(0)
            end
            it 'uname -a should succeed and output Linux' do
              output = image.cmd(['uname', '-a'])
              expect(output[:stdout]).to match(/Linux/)
              expect(output[:stderr]).to be_nil
              expect(output[:return_code]).to eq(0)
            end
            it 'false should fail' do
              output = image.cmd(['false'])
              expect(output[:stdout]).to be_nil
              expect(output[:stderr]).to be_nil
              expect(output[:return_code]).to eq(1)
            end
            it 'test stderr output' do
              output = image.cmd(['sh','-c','echo test123 >&2'])
              expect(output[:stdout]).to be_nil
              expect(output[:stderr]).to match(/test123/)
              expect(output[:return_code]).to eq(0)
            end
          end
        end
      end
    end
  end
end
