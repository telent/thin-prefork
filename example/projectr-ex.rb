# This example shows how you would put Thin::Prefork together with Projectr
# to get automatic reloading of source files when something changes.

require 'projectr'
require 'projectr/inotify'
$:.push "lib"
require 'thin/prefork'
require 'thin/prefork/project'

require 'sinatra/base'

Projectr::Project.new :hello do
  class << self
    include Projectr::Inotify
  end
  directory :lib do
    file "file1"
    file "file2"
  end
end

h=Projectr::Project[:hello]
h.load!

master=Thin::Prefork::Project.new :num_workers=>2,
:project=>:hello,:app_class=>HelloWorld,
:host=>"0.0.0.0",:port=>1974,:stderr=>$stderr

master.run!
