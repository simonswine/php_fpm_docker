require 'spec_helper'
require 'php_fpm_docker/application'

module PhpFpmDocker
  describe Application do
    let(:a_i) do
      described_class.new
    end
    before(:example) do
      @options = {
        dir: Pathname.new(Dir.mktmpdir)
      }

      # Mock docker api
      mock_docker_api

      # Mock users
      @users = {
        1001 => 'user1',
        1002 => 'user2',
        2001 => 'luser1',
        2002 => 'luser2',
      }
      mock_users

      @groups = {}
      @users.each do |key,value|
        @groups[key] = value.sub('user','group')
      end
      mock_groups

      # Mock path detection
      allow_any_instance_of(DockerImage).to receive(:detect_output).and_return([
        'spawn_fcgi_path=/spawn_fcgi_path',
        'php_path=/php_path',
        'PHP 5.6.3 (cgi-fcgi) (built: Nov 17 2014 14:14:17)',
      ])

      # Mock log dir
      @options[:log_dir] = @options[:dir].join 'log'
      allow(Application).to receive(:log_dir_path).and_return(@options[:log_dir])
      allow(Application).to receive(:log_path).and_return(Pathname.new(
        File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'tmp', 'rspec.log'))
      ))

      # Wrap creation of Launchers
      allow(Launcher).to receive(:new).and_wrap_original do |m, *args|
        i=m.call(*args)
        # Don't fork to background
        allow(i).to receive(:fork) do |&block|
          block.call
        end.and_return(-1)
        # Disable sleep
        allow(i).to receive(:sleep)
        i
      end
      # Disable detaching
      allow(Process).to receive(:detach)

      # Break Kernel Loop after first run
      allow(Kernel).to receive(:loop) do |&block|
        block.call
      end

      # Mock www dir 
      @options[:web_dir] = @options[:dir].join 'web'

      # Mock run dir 
      @options[:pid_dir] = @options[:dir].join 'run'
      allow(a_i).to receive(:pid_dir_path).and_return(@options[:pid_dir])

      # Mock config dir
      @options[:config_dir] = @options[:dir].join 'config'
      allow(a_i).to receive(:config_dir_path).and_return(@options[:config_dir])
      @options[:launchers] = 1
      @options[:pools] = 2
      create_config @options
    end
    describe 'init.d script' do
          let(:start) do
            expect{start_method}.to output.to_stdout
            start_method
          end
          let(:start_method) do
            allow(a_i).to receive(:exit).with(0)
            a_i.run(['launcher1','start'])
          end
          
      context 'one launcher' do
        context 'start' do
          let(:method) do
            start
          end
          it 'should return successful return value' do
            expect(a_i).to receive(:exit).with(0)
            method
          end
          context 'starts two containers' do
            before(:example) do
              method
            end
            it 'should be started' do
              expect(@docker_api_containers.keys).to contain_exactly(
                match(/web1_/),
                match(/web2_/)
              )
            end
            it 'should get the correct bind_mounts' do
              matching = [
                match(%r{^/var/lib/php5-fpm(:|$)}),
                match(%r{^/var/www/web[0-9]+domain\.com(:|$)}),
              ]
              @docker_api_containers.each do |key,value|
                expect(value[:start_args].first['Binds']).to contain_exactly(
                  *matching
                )
                expect(value[:create_args].first['Volumes'].keys).to contain_exactly(
                  *matching
                )
              end
            end
            it 'should get the correct command' do
              @docker_api_containers.each do |key,value|
                command = value[:create_args].first['Cmd']
                expect(command.join(' ')).to match(/-M 0660/)
                expect(command.join(' ')).to match(%r{/spawn_fcgi_path.+--.+/php_path})
                ['u','U','g','G'].each do |char|
                  expect(command.join(' ')).to match(/-U [0-9]+/)
                end
              end
            end
          end
        end
        context 'start and stop' do
          let(:method) do
            start
          end
          let(:launchers) do
            inst_get(:@launchers)
          end
          it 'should return successful return value' do
            expect(a_i).to receive(:exit).with(0)
            method

            # Loop containers
            @docker_api_containers.each do |key,value|
              expect(value[:object]).to receive(:delete).with(hash_including(:force => true))
            end
            launchers.first.stop_pools
          end
        end
      end
    end
  end
end
