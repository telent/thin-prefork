# A preforking multi-process Rack web server based on Thin

Run a small cluster of Thin servers, to allow for multiple
simultaneous "long" requests without having the whole world hang, to
take advantage of multicore CPUs, and all those other things that make
a single-request-at-a-time production server a bad idea.

Note that each worker runs on its own port, so you will need a
frontend server (something like nginx or loadbal or varnish) to
provide a single endpoint for the net at large and divvy up incoming
requests between the backends

You might want to use this instead of the default thin(1) command line
tool if:

* you wish to know which port a given worker is running on, when that
  worker starts up.  I want to vary the number of workers dynamically
  without also having to edit the configuration file used by the
  upstream load balancer.  DRY and all that.

* you are trying to play nice with sysvinit scripts and want one pid
  file with the same name as you supplied to `--pid`, not n of them
  with slight variations on it

* you want to introduce custom behaviours when your app is started,
  stopped, or restarted

* you want to define your own mechanisms (for example, signal handlers
  or inotify/fsevent events or a control socket) for *telling* your
  app that it is to be restarted or that its environment has changed

* in general, you'd rather write ruby than shell script 

## Overview

**Thin::Prefork::Worker** is a single process which does two things.  One:
it answers incoming web requests one at a time - as you'd expect from
a single process web server - and two: it listens on one end of an
internal socket for commands from the master, and calls methods when
it gets them. 

The standard Worker understands the commands `start!`, `reload!` and
`stop!`, which respectively do nothing, cause it to exit, and cause it
to exit.  To make it do anything more interesting you must subclass it
with additional (or better) implementations of methods! whose! names!
end! in! !

**Thin::Prefork** is the master server.  It forks off children which run
(your subclass of) Thin::Prefork::Worker, restarts them when they die,
and sends commands to them over the internal socket connection.

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

To get this, 

     require 'projectr'
     require 'thin/prefork/projectr'

and then use Thin::Prefork::Projectr instead of Thin::Prefork
