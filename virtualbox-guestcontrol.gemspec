# -*- encoding: utf-8 -*-
require File.expand_path('../lib/virtualbox-guestcontrol/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Andrew Eberbach"]
  gem.email         = ["andrew@ebertech.ca"]
  gem.description   = %q{Runs stuff inside of a VirtualBox VM}
  gem.summary       = %q{Runs stuff inside of a VirtualBox VM}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "virtualbox-guestcontrol"
  gem.require_paths = ["lib"]
  gem.version       = VirtualBox::GuestControl::VERSION
  
  gem.add_dependency 'shellter'
  gem.add_dependency 'activesupport', "~> 3.0"
  gem.add_dependency 'clamp'
end
