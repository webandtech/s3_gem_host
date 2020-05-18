# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 's3_gem_host/version'

Gem::Specification.new do |spec|
  spec.name          = 's3_gem_host'
  spec.version       = S3GemHost::VERSION
  spec.authors       = ['Aaron Severs']
  spec.license       = 'MIT'

  spec.summary       = 'Rake tasks to enable using Amazon S3 as a Ruby gem server'
  spec.description   = 'Provides Rake tasks to manage gem hosting on AWS S3 without the need for a separate gem '\
                       'server. This is especially useful for hosting private gems.'
  spec.homepage      = 'https://github.com/WebAndTech/s3_gem_host'
  spec.require_paths = ['lib']
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_dependency 'aws-sdk-s3', '~> 1.64'
  spec.add_dependency 'builder'
  spec.add_dependency 'bundler'
  spec.add_dependency 'rake'
end
