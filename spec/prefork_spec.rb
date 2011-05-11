require 'thin/prefork'
require 'net/http'
require 'sinatra/base'
require 'socket'

class App < Sinatra::Base
  get '/' do 
    content_type "text/plain"
    "hello"
  end
  get '/var/*' do |var|
    (eval "$#{var}").to_s
  end
end

module TestRegister
  def on_register
    $register=$$
  end
end

module TestKidHooks
  def on_start
    $start="child #{$$}"
  end
  
  def on_stop 
    $stop="child #{$$}"
  end
end


module TestFrobnitz
  def frobnitz
    self.send_control_message(:frobnitz)
  end
  def child_frobnitz
    $frobnitz="frobnitz"
  end
end

module TestZebedee
  $zebedee=''
  def zebedee
    self.send_control_message(:zebedee)
  end
  def child_zebedee
    $zebedee << "child"
  end
  def on_zebedee
    $zebedee << "hook"
  end
end

describe Thin::Prefork do
  def get(url)
    Net::HTTP.get(URI.parse(url))
  end

  def start(args={})
    args={:app=>App,
      :num_workers=>1,:stderr=>$stderr}.merge(args)
    @kid=Kernel.fork do
      s=Thin::Prefork.new(args)
      Signal.trap("TERM") do
        s.stop!
      end
      if block_given? then
        Signal.trap("USR1") do
          warn [:sigusr1]
          yield s
        end
      end
      s.run!
    end
    sleep 2
    if block_given? then
      Process.kill("USR1",@kid)
      warn [:sending,:sigusr1]
      sleep 1
    end
  end

  before(:each) do 
    @kid=nil
  end

  after(:each) do 
    @kid and Process.kill("TERM",@kid)
  end

  it "answers requests on address w.x.y.z port n when started on that endpoint" do
    start :address=>"127.0.0.1",:port=>3000
    get('http://127.0.0.1:3000/').should == 'hello'
    
    # try to find another address on the local machine that isn't
    # 127.0.0.1
    if h=UDPSocket.open {|s| s.connect('github.com',1) ; s.addr.last} then
      Proc.new { get("http://#{h}:3000/") }.should raise_error
    end

  end
  it "binds to all addresses when started without :address option" do
    start :port=>3000
    get('http://127.0.0.1:3000/').should == 'hello'
    if h=UDPSocket.open {|s| s.connect('github.com',1) ; s.addr.last} then
      get("http://#{h}:3000/").should == 'hello'
    end
  end

  it "listens to ports n .. n+j when started with j workers" do
    j=4;n=3000
    start :port=>n,:num_workers=>j
    sleep 2
    n.upto(n+j-1) do |port|
      u="http://127.0.0.1:#{port}/"
      get(u).should == 'hello'
    end
  end

  it "runs on_register in the parent process" do
    start :port=>3000,:worker_mixins=>[TestRegister]
    get("http://127.0.0.1:3000/var/register").to_i.should == @kid
  end
  
  it "runs on_start once in each child process and not in the parent" do
    start :port=>3000,:worker_mixins=>[TestKidHooks]
    get("http://127.0.0.1:3000/var/start").should match /child/
  end

  it "runs on_stop once in each child process and not in the parent" do
    pending "not sure how the hell we test this"
    start :port=>3000,:worker_mixins=>[TestKidHooks]
    get("http://127.0.0.1:3000/var/stop").should_not match /child/
  end

  it "runs on_unregister in the parent process" do
    pending "or this"
  end

  # these don't work because there's no frobnitz or zebedee methods 
  # in the master object, nor any way for us to test it if there were
  
  it "runs child_frobnitz in the child when a frobnitz command is mixed in" do
    start :port=>3000,:worker_mixins=>[TestFrobnitz] do |s|
      s.workers.each do |w|
        w.frobnitz
      end
    end
    get("http://127.0.0.1:3000/var/frobnitz").should match /frobnitz/
  end
  
  it "runs both on_zebedee and child_zebedee in the child when a zebedee command is mixed in and on_zebedee exists" do
    start :port=>3000,:worker_mixins=>[TestZebedee] do |s|
      s.workers.each do |w|
        w.zebedee
      end
    end
    v=get("http://127.0.0.1:3000/var/zebedee")
    v.should match /child/
    v.should match /hook/
  end
end
