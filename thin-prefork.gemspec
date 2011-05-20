 
Gem::Specification.new do |s|
  s.name        = "thin-prefork"
  s.version     = "0.03"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Daniel Barlow"]
  s.email       = ["dan@telent.net"]
  s.summary     = "A customizable preforking server which starts a small cluster of 'thin'-backed rack applications on a single host"
  s.description = "thin-prefork allows the creation of a multiprocess preforking server running 'thin' on several ports of one host, to take advantage of multiple CPU cores and/or to mitigate the effect of slow requests when there are multiple simultaneous clients.  When used with Projectr, includes support for automatic reloading of application files when they change"
  s.required_rubygems_version = ">= 1.3.6"
#  s.rubyforge_project         = "bundler"
 
  s.add_development_dependency "rspec"
 
  s.files        = Dir.glob("{lib,example}/**/*") + %w(README.md)
#  s.executables  = ['bundle']
  s.require_path = 'lib'
end
