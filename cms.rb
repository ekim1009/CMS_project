require 'sinatra' 
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, "cb53ec5f9d72f8edc5acca50424dd78bbe7d213db7d32fb9bbffbfb8cdba8539" 
end

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
    erb render_markdown(content)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
    YAML.load_file("users.yml")
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# getting to the home page
get '/' do
  pattern = File.join(data_path, "*")
  @filename = "CMS"
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  
  erb :home, layout: :layout
end

# opening a document
get "/:filename" do
  require_sign_in
  
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]
  if @filename == 'new' 
    erb :new, layout: :layout
  elsif File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

def valid_credentials?(username, password)
  # credentials = load_user_credentials

  # if credentials.key?(username)
  #   bcrypt_password = BCrypt::Password.create(password)
  #   bcrypt_password == password
  # else
  #   false
  # end
  credentials = load_user_credentials
  bcrypt_password = BCrypt::Password.create(password)
  credentials.key?(username) && bcrypt_password == password
end

def user_signed_in?
  session.key?(:username)
end

def require_sign_in
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# editing a document
get "/:filename/edit" do
  require_sign_in
  
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]
  @text = File.read(file_path)
  erb :edit, layout: :layout
end

def valid_input(text)
  text[-4..-1] == ".txt" || text[-3..-1] == ".md" ? true : false
end

# creating a new document
post "/new" do
  require_sign_in 
  
  file_path = File.join(data_path, params[:filename])
  
  if valid_input(params[:filename])
    File.open(file_path,"w")
    session[:message] = "#{params[:filename]} was created."
    redirect "/"
  else
    session[:message] = "Only '.txt' and '.md' files are supported."
    status 422
    erb :new, layout: :layout
  end
end

# updating an existing document
post "/:filename" do
  require_sign_in
  
  file_path = File.join(data_path, params[:filename])
  text = params[:new_text]
  File.write(file_path, text)
  @filename = params[:filename]
  
  session[:message] = "#{@filename} has been updated."
  redirect "/"
end

# deleting a document
post "/:filename/delete" do
  require_sign_in
  
  file_path =  File.join(data_path, params[:filename])
  File.delete(file_path)
  
  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

def duplicate_filename(string)
  if string[-4..-1] == ".txt"
    string.insert(-5, "_dup")
  else 
    string.insert(-4, "_dup")
  end
end


# make a duplicate of a file
post "/:filename/duplicate" do
  require_sign_in
  
  file_path = File.join(data_path, params[:filename])
  content = File.read(file_path)
  new_filename = duplicate_filename(params[:filename])
  new_file = File.join(data_path, new_filename)
 

  File.new(new_file, "w")
  File.write(new_file, content)
  
  session[:message] = "A duplicate called #{new_filename} was created."
  redirect "/"
end

# create an account page
get "/users/createaccount" do
  erb :createaccount, layout: :layout
end

def password_match(str1, str2)
  str1 == str2 
end

def valid_username(str)
  str.strip.size > 1
end

# creating a new account
post "/users/createaccount" do
  username = params[:username]
  password = params[:password]
  retype_password = params[:retype_password]
  if !valid_username(username) 
    session[:message] = "You must input a valid username"
    status 422
    erb :createaccount, layout: :layout
  elsif !password_match(password, retype_password)
    session[:message] = "The passwords need to match"
    status 422
    erb :createaccount, layout: :layout
  else
    session[:message] = "Your account has been created"
    encrypt_password = BCrypt::Password.create(params[:password]).to_s
    data = YAML.load_file("users.yml")
    data[username] = encrypt_password
    File.open("users.yml", 'w') { |f| YAML.dump(data, f) } 
    redirect "/"
  end
end

# sign in page
get "/users/signin" do
  erb :signin, layout: :layout
end

# signing in
post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

# signing out
post "/user/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end


