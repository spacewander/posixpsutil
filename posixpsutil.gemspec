$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "posixpsutil/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'posixpsutil'
  s.version     = POSIXPSUTIL::VERSION
  s.authors     = ["spacewander"]
  s.email       = ["spacewanderlzx@gmail.com"]
  s.homepage    = 'https://github.com/spacewander/posixpsutil'
  s.summary     = 'A posix processes and system utilities monitor in Ruby'
  s.platform    = Gem::Platform.local
  s.description = 'posixpsutil is a ruby gem which shows processes and system information for you'
  s.files       = Dir["lib/**/*"] + Dir["ext/**/*"] + ["README.md", "Rakefile", "make.rb"]
  s.test_files  = Dir["test/*"]
  s.extensions  << 'ext/Rakefile'
  s.license     = 'new BSD'
  s.required_ruby_version = '>= 1.9'
  s.add_dependency 'ffi', '~> 1.9'
end
