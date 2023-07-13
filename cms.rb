require 'sinatra' 
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, "cb53ec5f9d72f8edc5acca50424dd78bbe7d213db7d32fb9bbffbfb8cdba8539" 
end

root = File.expand_path("..", __FILE__)

def render_markdown(arg)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(arg)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

get '/' do
  @files = Dir.glob("data/*").map do |path|
    File.basename(path)
  end
  
  erb :home, layout: :layout
end

get "/:filename" do
  file_path = root + "/data/" + params[:filename]
  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  path = root + "/data/" + params[:filename]
  @filename = params[:filename]
  @text = File.read(path)
  erb :edit, layout: :layout
end

post "/:filename" do
  path = root + "/data/" + params[:filename]
  text = params[:new_text]
  File.write(path, text)
  @filename = params[:filename]
  
  session[:message] = "#{@filename} has been updated."
  redirect "/"
end

