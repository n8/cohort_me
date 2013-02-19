# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cohort_me/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["nate"]
  gem.email         = ["nate.kontny@gmail.com"]
  gem.description   = %q{Cohort analysis for a Rails app}
  gem.summary       = %q{Provides tools to Ruby and Rails developers to perform cohort analysis.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "cohort_me"
  gem.require_paths = ["lib"]
  gem.version       = CohortMe::VERSION
end
