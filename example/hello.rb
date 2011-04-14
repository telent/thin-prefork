require 'sinatra/base'
$:.push "lib"
require 'thin/prefork'

class HelloApp < Sinatra::Base
  set :run, false
  set :logging, true
  set :show_exceptions, true
  set :dump_errors,true

  get '/' do 
    '<html><head><title>Hello world</title></head>'+
      '<body><h1>Hello</h1>'+
      '</body></html>'
  end
  
  get '/google' do
    redirect "http://www.google.com/?q=thin+prefork&btnI=true"
  end
end

master=Thin::Prefork.new :app=>HelloApp.new,:num_workers=>1,
:host=>"0.0.0.0",:port=>1974,:stderr=>$stderr

master.run!
