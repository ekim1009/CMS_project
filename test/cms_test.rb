ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
  
  def test_home
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end
  
  def test_link
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto"
  end
  
  def test_non_existent_page
    get "/what.txt"
    assert_equal 302, last_response.status
    
    get last_response["location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "what.txt does not exist"
    
    get "/"
    refute_includes last_response.body, "does not exist."
  end
end