# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'php_fpm_docker/version'

Gem::Specification.new do |spec|
  spec.name          = 'php_fpm_docker'
  spec.version       = PhpFpmDocker::VERSION
  spec.authors       = ['Christian Simon']
  spec.email         = ['simon@swine.de']
  spec.description   = 'Use docker containers for PHP from FPM config'
  spec.summary       = 'Use docker containers for PHP from FPM config'
  spec.homepage      = 'https://github.com/simonswine/php_fpm_docker'
  spec.license       = 'GPLv3'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = ['lib']

  spec.add_dependency 'docker-api'
  spec.add_dependency 'inifile'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rspec'

end
