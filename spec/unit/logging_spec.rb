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
      stub_const("PhpFpmDocker::LOG_FILE", @stringio)
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
