require 'coveralls'
require 'helper'

Coveralls.wear! do
  add_filter 'spec/'
end

# Set load path for this module
dir = File.expand_path(File.join(File.dirname(__FILE__),'..'))
$LOAD_PATH.unshift File.join(dir, 'lib')

RSpec.configure do |config|
  config.include Helper

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
end
