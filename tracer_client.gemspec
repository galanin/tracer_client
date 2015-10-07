# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tracer_client/version'

Gem::Specification.new do |spec|
  spec.name          = 'tracer_client'
  spec.version       = TracerClient::VERSION
  spec.authors       = ['Serge Galanin']
  spec.email         = ['s.galanin@gmail.com']

  spec.summary       = %q{Tracer API}
  spec.description   = %q{Log errors and objects changes to Tracer.}
  spec.homepage      = "https://github.com/galanin/tracer_client"
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'config', '~> 1.0'
  spec.add_dependency 'rails', '~> 4.2'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
end
