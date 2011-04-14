require 'eventmachine'
require 'thin'
require 'socket'

#Thin=Module.new

class Thin::Prefork
  module NamedArgs
    def set_attr_from_hash(args)
      args.each {|k,v|
        k="#{k}=".to_sym; self.public_methods.include?(k) and self.send(k,v)
      }
    end
  end

  attr_accessor :num_workers,:app,:host,:port,:stderr,:slow_start,:pid_file
  attr_accessor :worker_class
  include NamedArgs

  def initialize(args)
    set_attr_from_hash(args)
    @respawn=true
    @slow_start||=2
    @worker_class||=Worker
    @workers=[]
  end

  def run!
    if @pid_file then
        File.open(pid,"w") do |f|
        f.print "#{Process.pid}\n"
      end
    end

    @num_workers.times do |i|
      @workers << @worker_class.new(:app=>@app,:host=>@host,:port=>i+@port,:stderr=>@stderr)
      sleep @slow_start
    end

    until @workers.empty?
      if block_given? then
        yield
      else
        a=[]
        IO.select(a,a,a,1)
      end
      if died=Process.wait(-1,Process::WNOHANG)
        w=@workers.find { |w| w.pid==died }
        if w && @respawn then
          @workers <<
            Worker.new(:app=>@app,:host=>w.host,:port=>w.port,:stderr=>@stderr)
        end
      end
    end
  end

  def reload!
    @workers.each do |w|
      w.send_control_message :reload!
      sleep @slow_start
    end
  end

  def stop!
    @respawn=false
    @workers.each do |w|
      w.send_control_message :stop!
    end
  end
end


class Thin::Prefork::Worker
  class Controller < ::EventMachine::Connection
    attr_accessor :worker
  end

  include Thin::Prefork::NamedArgs
  attr_accessor :app,:control_socket,:pid,:host,:port,:stderr

  def initialize(args)
    set_attr_from_hash(args)
    warn [:initailze,@app]
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
            if (command[-1]=="!") && (self.worker.respond_to?(command.to_sym)) then
              self.worker.send(command.to_sym,*tokens)
            end
          end
        end
        self.start!
        warn [:app,@app]
        Rack::Handler::Thin.run(@app,:Host=>@host, :Port=>@port)
      end
    end
  end
  def send_control_message(message)
    @control_socket.puts(message.to_s)
  end

  # Override this to do any per-worker initialisation (which might
  # include, for example, loading your application code) required
  # before beginning to serve requests.  This is called inside
  # Eventmachine.run
  def start!
    true
  end

  # This is called when the parent process receives a SIGHUP or other
  # indication that we should reinitialise our state.  You can use it
  # to reload configuration files or application code, etc.  The
  # default method exits, thus causing the parent to start another
  # worker in our place
  def reload!
    warn "reloading not supported"
    stop!
  end

  def stop!
    exit 0
  end
end
