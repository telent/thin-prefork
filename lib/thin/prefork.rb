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
      a=@io_handlers.keys.dup
      fin,fout,fe=IO.select(a,a,a,1)
      @io_handlers.keys.each do |io|
        if fin && fin.member?(io) && blk=@io_handlers[io] then
          blk.call(:in)
        end
        if fout && fout.member?(io) && blk=@io_handlers[io] then
          blk.call(:out)
        end
        if fe && fe.member?(io) && blk=@io_handlers[io] then
          blk.call(:exception)
        end
      end
      if died=Process.wait(-1,Process::WNOHANG)
        if @respawn then
          w=@workers.delete { |w| w.pid==died }
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

