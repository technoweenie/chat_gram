require 'test/unit'
require 'rubygems'
require 'bundler'
Bundler.require(:test)

ENV["INSTAGRAM_LAT"]   = 'lat'
ENV["INSTAGRAM_LNG"]   = 'lng'
ENV['CAMPFIRE_PHOTO']  = 'photo'
ENV['CAMPFIRE_DEBUG']  = 'debug'
ENV['CAMPFIRE_DOMAIN'] = "none"
ENV['DATABASE_URL']    = 'sqlite:/'

require File.expand_path('../instagram_campfire_hook', __FILE__)

Instagram.configure do |c|
  c.adapter = :test
end

class InstagramCampfireHookApp
  set :environment, :test
  set :campfire_http do
    obj = Object.new
    def obj.post(room, hash)
      $messages << [room.chomp("/speak.json"), hash[:message][:body]]
    end
    obj
  end

  set :instagram_client, Instagram.client
end

class Instagram::API
  attr_accessor :stubs
  def connection(raw = false)
    options = {
      :headers => {'Accept' => "application/#{format}; charset=utf-8", 'User-Agent' => user_agent},
      :proxy => proxy,
      :ssl => {:verify => false},
      :url => endpoint,
    }

    Faraday.new(options) do |connection|
      connection.use Faraday::Request::OAuth2, client_id, access_token
      connection.adapter(:test, @stubs)
      connection.use Faraday::Response::RaiseHttp5xx
      unless raw
        case format.to_s.downcase
        when 'json' then connection.use Faraday::Response::ParseJson
        end
      end
      connection.use Faraday::Response::RaiseHttp4xx
      connection.use Faraday::Response::Mashify unless raw
    end
  end
end

class InstagramCampfireHookTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def test_receives_webhook
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") { stubbed_image }

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media',
      :time => 1297286541}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal ['photo', 'image!'], $messages.pop
    assert_equal ['photo', 'caption! at location! by user! link!'], $messages.pop
    assert_nil $messages.pop
  end

  def test_receives_webhook_without_caption
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") do
      stubbed_image :caption => nil
    end

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media',
      :time => 1297286541}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal ['photo', 'image!'], $messages.pop
    assert_equal ['photo', 'location! by user! link!'], $messages.pop
    assert_nil $messages.pop
  end

  def test_receives_webhook_without_location
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") do
      stubbed_image :location => nil
    end

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media',
      :time => 1297286541}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal ['photo', 'image!'], $messages.pop
    assert_equal ['photo', 'caption! by user! link!'], $messages.pop
    assert_nil $messages.pop
  end

  def test_receives_webhook_without_location_or_caption
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") do
      stubbed_image :caption => nil, :location => nil
    end

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media',
      :time => 1297286541}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal ['photo', 'image!'], $messages.pop
    assert_equal ['photo', 'by user! link!'], $messages.pop
    assert_nil $messages.pop
  end

  def test_searches_by_location
    @instagram.stubs.get("/v1/media/search.json?lat=lat&lng=lng&max_timestamp=&min_timestamp=") do
      stubbed_image
    end

    get "/search"
    assert_equal "caption! at location! by user! link!\nimage!", last_response.body
  end

  def test_responds_to_challenge
    get '/image', 'hub.challenge' => 'abc'
    assert_equal 'abc', last_response.body
  end

  def setup
    $messages = []
    @instagram = InstagramCampfireHookApp.settings.instagram_client
    @instagram.stubs = Faraday::Adapter::Test::Stubs.new
  end

  def app
    InstagramCampfireHookApp
  end

  def stubbed_image(custom={})
    [200, {}, Yajl.dump(:data => [{
      :caption  => {:text => 'caption!'},
      :location => {:name => 'location!'},
      :user     => {:username => 'user!'},
      :link     => 'link!',
      :images   => {:standard_resolution => {:url => 'image!'}}
    }.update(custom)])]
  end
end
