require 'spec_helper'
require 'php_fpm_docker/logging'

describe PhpFpmDocker::Logging do
  describe '#logger' do
    class TestClassA
      extend PhpFpmDocker::Logging
    end
    class TestClassB
      include PhpFpmDocker::Logging
    end
    before(:example) do
      @stringio = StringIO.new
      @dbl_app = double('PhpFpmDocker::Application')
      allow(@dbl_app).to receive(:log_path).and_return(@stringio)
      stub_const("PhpFpmDocker::Application", @dbl_app)
    end
    after(:example) do
      expect(@stringio.string).to match(/message1/)
      expect(@stringio.string).to match(/INFO/)
    end
    it 'should log to io' do
      TestClassA.logger.info 'message1'
      expect(@stringio.string).to match(/\[TestClassA/)
    end
    it do
      i=TestClassB.new
      i.logger.info 'message1'
      expect(@stringio.string).to match(/#<TestClassB/)
    end
  end
end
