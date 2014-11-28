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

      # Mock log dir
      @options[:log_dir] = @options[:dir].join 'log'
      allow(Application).to receive(:log_dir_path).and_return(@options[:log_dir])
      allow(Application).to receive(:log_path).and_return(STDOUT)

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
    describe '#run' do
      it 'starts containers' do
        puts @options[:dir]
        method(['launcher1','start'])
      end
    end
  end
end
