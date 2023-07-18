ENV["RACK_ENV"] = "test"

require "fileutils"
require "minitest/autorun"
require "rack/test"
require "yaml"


require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end
  
  def session
    last_request.env["rack.session"]
  end
  
  def admin_session
    { "rack.session" => { username: "admin" } }
  end
  
  def test_home
    create_document "about.md"
    create_document "changes.txt"
    
    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    
  end
  
  def test_link
    create_document "history.txt", "1993 - Yukihiro Matsumoto"
    
    get "/history.txt", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto"
  end
  
  def test_non_existent_page
    get "/what.txt", {}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "what.txt does not exist.", session[:message]
  end
  
  def test_viewing_markdown_document
    create_document "about.md", "# Ruby is..."
    
    get "/about.md", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end
  
  def test_editing_documents_page
    create_document "sample.txt"
    
    get "/sample.txt/edit", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea name=\"new_text\""
  end

  def test_updating_document
    post "/sample.txt", {new_text: "new_text"}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "sample.txt has been updated.", session[:message]
    
    get '/sample.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new_text"
  end
  
  def test_updating_document_signed_out
    post "/sample.txt", { new_text: "new_text" }
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_view_new_document
    get "/new", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Add a new document:"
  end
  
  def test_view_new_document_signed_out
    get "/new"
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_create_new_doc
    post "/new", { filename: "test.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:message]
    
    get '/'
    assert_includes last_response.body, "test.txt"
  end
  
  def test_create_new_doc_signed_out
    post "/new", { filename: "test.txt" }
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_invalid_new_doc_name
    post "/new", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end
  
  def test_delete_doc
    create_document "sample.txt"
    
    post "/sample.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "sample.txt has been deleted.", session[:message]
    
    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end
  
  def test_delete_doc_signed_out
    create_document "sample.txt"
    
    post "/sample.txt/delete", { filename: "test.txt" }
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_signin_form
    get "/users/signin"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "label for"
  end
  
  def test_signin
    #fix
    # credentials = YAML.load_file("test/users.yml")
    # user = credentials.key
    # pass = credentials.value
    post "/users/signin", username: "admin", password: "secret"
    
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]
    
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end
  
  def test_bad_signin
    post "users/signin", username: "hello", password: "world"
    
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials."
  end
  
  def test_signout
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"
    
    post "user/signout"
    assert_equal "You have been signed out.", session[:message]
    
    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "<a href=\"/users/signin\">Sign In</a>"
  end
  
end