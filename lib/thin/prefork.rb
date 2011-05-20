require 'eventmachine'
require 'thin'
require 'socket'

Thin::Prefork=Class.new

require_relative 'prefork/named_args'
require_relative 'prefork/worker'

class Thin::Prefork  
  attr_accessor :num_workers,:app,:host,:port,:stderr,:slow_start,:pid_file
  attr_accessor :worker_mixins
  attr_reader :workers
  include NamedArgs

  def initialize(args)
    args[:host]||=args[:address]
    set_attr_from_hash({num_workers: 3, slow_start: 0.5, 
                         host: "0.0.0.0", port: 1974,
                         worker_mixins: []
                       }.merge(args))
    unless @app then
      raise Exception,"Required parameter :app is null"
    end
    @respawn=true
    @worker_class=Class.new(Worker)
    mixins=@worker_mixins.respond_to?(:each) ? @worker_mixins : [@worker_mixins]
    @worker_class.class_eval do
      mixins.each { |m| include m }
    end
    @workers=[]
    @io_handlers={}
  end

  # add a handler to watch for file i/o in the parent process.  +io+ 
  # is an object which responds to #to_io withan IO object: when it
  # becomes available for read/write/exceptions, the supplied block will
  # be called with +io+ as an argument
  def add_io_handler(io,&blk)
    @io_handlers[io]=blk
  end

  def run!
    if @pid_file then
      File.open(@pid_file,"w") do |f|
        f.print "#{Process.pid}\n"
      end
    end
    
    @num_workers.times do |i|
      w=@worker_class.new(:app=>self.app,:host=>@host,:port=>i+@port,:stderr=>@stderr)
      @workers << w.start
      sleep @slow_start
    end

    until @workers.empty?
      a=@io_handlers.keys.map(&:to_io)
      fin,fout,fe=IO.select(a,a,a,1)
      @io_handlers.keys.each do |o|
        io=o.to_io
        if fin && fin.member?(io) && blk=@io_handlers[o] then
          blk.call(o,:in)
        end
        if fout && fout.member?(io) && blk=@io_handlers[o] then
          blk.call(o,:out)
        end
        if fe && fe.member?(io) && blk=@io_handlers[o] then
          blk.call(o,:exception)
        end
      end
      if died=Process.wait(-1,Process::WNOHANG)
        if @respawn then
          w=@workers.find { |w| w.pid==died }
          if w then w.start end
        end
      end
    end
    @pid_file and File.delete @pid_file
  end

  def stop!
    @respawn=false
    @workers.each { |w| w.stop; w.unregister }
    @workers=[]
  end
end

