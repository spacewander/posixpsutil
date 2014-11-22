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
  s.summary     = 'A posix process and system utilities module for Ruby'
  s.description = 'posixpsutil is a ruby gem which shows process and system information for you'
  s.files       = Dir["lib/**/*"] + ["README.md", "Rakefile"]
  s.test_files  = Dir["test/*"]
  s.license     = 'new BSD'

end
