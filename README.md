# A preforking multi-process Rack web server based on Thin

Run a small cluster of Thin servers, to allow for multiple
simultaneous "long" requests without having the whole world hang, to
take advantage of multicore CPUs, and all those other things that make
a single-request-at-a-time production server a bad idea.

Note that each worker runs on its own port, so you will need a
frontend server (something like nginx or loadbal or varnish) to
provide a single endpoint for the net at large and divvy up incoming
requests between the backends.

Philosophically(sic) speaking, this is a library not an application,
and as such it tries hard to avoid doing "magic" or locking you into
assumptions about how you wish to use it.  You might want to use it
instead of the default thin(1) command line tool if:

* you wish to know which port a given worker is running on, when that
  worker starts up.  I want to vary the number of workers dynamically
  without also having to edit the configuration file used by the
  upstream load balancer.  DRY and all that.

* you are trying to play nice with sysvinit scripts and want one pid
  file with the same name as you supplied to `--pid`, not n of them
  with slight variations on it

* you want to introduce custom behaviours (e.g. opening persistent
  connections external to daemons) when your app is started or stopped

* you want a protocol for telling each worker process to execute
  commands that you specify (for example, dumping performance or
  uptime data to an analysis tool, or reconnecting to an external process
  that ha been restarted) on demand

* you want to define your own mechanisms (for example, signal handlers
  or inotify/fsevent events or a control socket) for telling your
  app that it is to be restarted or that its environment has changed

* in general, you'd rather write ruby than shell script.

## Overview

**Thin::Prefork::Worker** runs a single process which does two things.
One: it answers incoming web requests one at a time - as you'd expect
from a single process web server - and two: it listens on one end of
an internal socket for commands from the master.  For any command
`foo` received, it calls an optional `on_foo` notification method if
any such method is defined, then the `child_foo` implementation method
(which is required to be implemented).  Commands are implemented by
mixing modules into T::P::W's inheritance chain.

**Thin::Prefork** is the master server.  It forks off children which
run Thin::Prefork::Worker, watches them (using Process.wait) to see
when they die, restarts them when necessary, and sends commands to
them over the internal socket connection.

The children run with stdin connected to /dev/null and stdout/stderr
connected to an IO object that you pass in when creating the master.
My suggestion would be a syslog connection, but it's your choice.


## Optional extras

Thin::Prefork is designed to be used with Projectr.  Projectr is a
very small DSL in which you can list all the files that your project
needs to load, plus dependencies of the form "if A has changed, you
will also need to reload B and C" (example: suppose A defines a DSL
and B is written using that DSL), and some logic to load whatever
files are missing or have been changed on disk since we last loaded
them.  It also includes some magic using rb-inotify such that you can
register a block to be called if any of the files change.  Can you see
where this is going?  That's right, you can have your app reload
automatically if the files in it change.


## Example usage

If you're using the Projectr add-in, you'd typically create a bin/server.rb 
that looks something like this:

    require 'projectr'
    require 'projectr/watch_changes'
    require 'thin/prefork/projectr'

    project=Projectr::Project[:myproject].load!
    server=Thin::Prefork::Server::Projectr.new :project=>project,:app=>MyApp

    server.add_io_handler(project.watch_changes) do |o|
      if o.changed_files.present? then
        server.reload
      end
    end
    Kernel.trap("SIGHUP") do |n|
      server.reload
    end

    server.start

This gets you reloading on SIGHUP or when Projectr detects that a
source file has changed.  You might want either or both or neither
depending on your environment (e.g dev vs production) but the good news
is it's your application, you can decide that yourself.

