guard :rspec, cmd: 'bundle exec rspec' do
  watch(/^spec\/.+_spec\.rb$/)
  watch(%r{^lib/php_fpm_docker/(.+:)\.rb$}) do |m|
    "spec/unit/#{m[1]}_spec.rb"
  end
  watch('spec/spec_helper.rb')  { 'spec' }
end
# vim: ft=ruby
