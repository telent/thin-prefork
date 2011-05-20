class Thin::Prefork::Worker
  module Lifecycle
    # To implement custom behaviours that hook into the worker thread
    # lifecycle, implement a module or modules that redefines some or
    # all of the methods in +Thin::Prefork::Worker::Lifecycle+.  Be sure
    # to call #super at the end of each redefined method.  Then pass the
    # module names in the :worker_mixins argument to Thin::Prefork#new
    
    # Worker lifecycle: 
    #
    # * on_register is called when the Worker object is created and added
    # to the worker pool 
    #
    # * on_start is called when an actual request-answering process is
    # * forked, and runs in the child process
    #
    # * on_stop is called when the child process is terminated by the
    # master, and runs in the child process.  The Worker continues to
    # live and may be asked later to start another process.  Note that
    # #on_stop may not be called if the child is terminated by other
    # means (e.g. a Unix signal sent externally by the +kill+ or the
    # Linux OOM killer)
    #
    # * on_unregister is called when the worker object is removed from the 
    # worker pool.  After this time the worker object is considered "dead"
    # and will not be used again
    #
    # It is possible (for example, during a code reload) to have
    # start/stop events fired multiple times without any calls to
    # create/destroy: the user is cautioned to think about whether his
    # custom behaviours are associated with the conceptual Worker or the
    # process which it may from time to time create and terminate to do
    # its actual job
    
    # Called directly after #initialize
    def on_register
    end
    
    # Called from the new child process inside Eventmachine.run.  Define
    # this to do any per-process initialisation (such as opening
    # per-process persistent connections to databases or remote services
    # or similar) required before beginning to serve requests.
    def on_start
    end
    
    # Define this to do any cleanup and resource release needed to
    # reverse the effect of your #on_start code.  This is called from
    # the child process before it exits
    def on_stop
    end
    
    # Define this to execute any cleanup required to reverse the effect
    # of your #on_register code
    def on_unregister
    end
  end

  class Controller < ::EventMachine::Connection
    attr_accessor :worker
  end

  include Thin::Prefork::NamedArgs
  attr_accessor :app,:control_socket,:pid,:host,:port,:stderr

  include Thin::Prefork::Worker::Lifecycle
  
  def initialize(args)
    set_attr_from_hash(args)
    self.on_register
  end
  
  def start
    @control_socket,control_client=
      Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)
    @pid=Kernel.fork do
      $stdout.reopen(@stderr)
      $stderr.reopen(@stderr)
      $stdin.reopen("/dev/null")
      @control_socket.close
      EM.run do
        EM.attach control_client,Controller do |c|
          c.worker=self
          def c.receive_data(data)
            tokens=data.chomp.split(/ /)
            command=tokens.shift
            if (self.worker.respond_to?(on=("on_"+command).to_sym)) then
              self.worker.send(on,*tokens)
            end
            self.worker.send(("child_"+command).to_sym,*tokens)
          end
        end
        self.on_start
        Rack::Handler::Thin.run(self.app,:Host=>@host, :Port=>@port)
      end
    end
    self
  end
  def send_control_message(message)
    @control_socket.puts(message.to_s)
  end

  def stop
    begin
      send_control_message(:stop)
    rescue Errno::EPIPE => e
      # the remote end sometimes shuts down particularly quickly,
      # causing us to get a failure from this message send which we
      # may safely ignore
    end
  end
  def child_stop
    exit 0
  end

  # this is unlike most of the other commands as the hooks run in the
  # parent thread not the child thread - there may or may not be a
  # child thread when this is called.
  def unregister
    on_unregister
  end
end
