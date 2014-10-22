# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongery/version'

Gem::Specification.new do |spec|
  spec.name          = "mongery"
  spec.version       = Mongery::VERSION
  spec.authors       = ["Tatsuhiko Miyagawa"]
  spec.email         = ["miyagawa@bulknews.net"]
  spec.summary       = %q{Convert MongoDB query to Arel for PostgreSQL + JSON}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "arel", ">= 4.0.2"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "pg"
end
