require 'bundler'
require 'bundler/version'

require File.expand_path('lib/version')

Gem::Specification.new do |s|
  s.add_development_dependency('rake')
  s.add_development_dependency "byebug"

  # s.add_development_dependency('fakeweb', '~> 1.3')
  # s.add_development_dependency('jnunemaker-matchy', '~> 0.4')
  # s.add_development_dependency('mocha', '~> 0.9')
  # s.add_development_dependency('shoulda', '~> 3.0.1')
  s.add_runtime_dependency('json')
  s.add_runtime_dependency('hashie', '~> 1.0')
  s.add_runtime_dependency('faraday', '~> 0.9')

  s.name = "tcc"
  s.author = "Kantox"
  s.description = %q{Implements some functionality of The Currency Cloud Connect API v2.}
  s.email = ["techservices@kantox.com"]
  s.executables = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  s.files = `git ls-files`.split("\n")
  s.homepage = "https://github.com/kantox/tcc_api"
  s.require_paths = ["lib"]
  s.summary = %q{A library which implements partially functionality of v2 of The Currency Cloud Connect API.}
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.version = TCC::VERSION
  s.platform = Gem::Platform::RUBY
  s.required_rubygems_version = Gem::Requirement.new('>= 1.3.6') if s.respond_to? :required_rubygems_version=
end