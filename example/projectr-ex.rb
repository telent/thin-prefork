# This example shows how you would put Thin::Prefork together with Projectr
# to get automatic reloading of source files when something changes.

require 'projectr'
require 'projectr/inotify'
$:.push "lib"
require 'thin/prefork'

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

class Worker < Thin::Prefork::Worker
  def start!
    Projectr::Project[:hello].load!
  end
  def reload!
    Projectr::Project[:hello]
  end
  def app
    HelloWorld.new
  end
end

h=Projectr::Project[:hello]
h.load!
master=Thin::Prefork::Projectr.new :worker_class=>Worker,:num_workers=>3,
:host=>"0.0.0.0",:port=>1974,:stderr=>$stderr

# set up the file watch
inotifier=h.watch_files do |project,name|
  warn [:changed_file, name]
  master.reload!
end

# register the filehandle for this notifier with the event loop 
# in #run!  The block is called when inotifier.to_io is "ready"
# for some class of I/O operation

master.add_io_handler(inotifier.to_io) do |direction|
  inotifier.process
end

master.run!
