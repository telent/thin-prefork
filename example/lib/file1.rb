warn "loading file1"

class HelloWorld < Sinatra::Base
  reset!
  set :run, false
  set :logging, true
  set :show_exceptions, true
  set :dump_errors,true

  get '/' do
    '<html><head><title>Hello world</title></head>'+
      '<body><h1>Hello everyone</h1>'+
      '</body></html>'
  end
  get '/google' do
    redirect "http://www.google.com/?q=thin+prefork&btnI=true"
  end
end
