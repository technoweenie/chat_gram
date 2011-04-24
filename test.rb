require 'test/unit'
require 'rubygems'
require 'bundler'
Bundler.require(:test)

ENV['TZ']              = 'UTC'
ENV["INSTAGRAM_LAT"]   = 'lat'
ENV["INSTAGRAM_LNG"]   = 'lng'
ENV['CAMPFIRE_ROOM']   = 'photo'
ENV['CAMPFIRE_DOMAIN'] = "none"
ENV['DATABASE_URL']    = 'sqlite:/'

require File.expand_path('../instagram_campfire_hook', __FILE__)

Instagram.configure do |c|
  c.adapter = :test
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
  class TestService
    attr_reader :messages
    def initialize
      @messages = []
    end

    def speak(text)
      @messages << text
    end
  end

  InstagramCampfireHookApp.set \
    :environment      => :test,
    :instagram_client => Instagram.client,
    :service          => (@@service = TestService.new)

  InstagramCampfireHookApp.settings.model.setup
  InstagramCampfireHookApp.settings.model.insert 'user!'

  include Rack::Test::Methods

  def test_receives_webhook
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") { stubbed_image }

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media'}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal 'image!', @@service.messages.pop
    assert_equal 'caption! at location! by user! on Thu, Feb 03, 2011 @ 05:18 AM link!', @@service.messages.pop
    assert_nil @@service.messages.pop
  end

  def test_receives_webhook_without_caption
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") do
      stubbed_image :caption => nil
    end

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media'}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal 'image!', @@service.messages.pop
    assert_equal 'location! by user! on Thu, Feb 03, 2011 @ 05:18 AM link!', @@service.messages.pop
    assert_nil @@service.messages.pop
  end

  def test_receives_webhook_without_location
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") do
      stubbed_image :location => nil
    end

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media'}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal 'image!', @@service.messages.pop
    assert_equal 'caption! by user! on Thu, Feb 03, 2011 @ 05:18 AM link!', @@service.messages.pop
    assert_nil @@service.messages.pop
  end

  def test_receives_webhook_without_location_or_caption
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") do
      stubbed_image :caption => nil, :location => nil
    end

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media'}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal 'image!', @@service.messages.pop
    assert_equal 'by user! on Thu, Feb 03, 2011 @ 05:18 AM link!', @@service.messages.pop
    assert_nil @@service.messages.pop
  end

  def test_receives_webhook_with_recent_time
    now = Time.now
    @instagram.stubs.get("/v1/users/1234/media/recent.json?") do
      stubbed_image :caption => nil, :location => nil,
        :created_time => Time.local(now.year, now.month, now.day, 21, 18).to_i
    end

    events = [{:subscription_id => 1, :object => 'user',
      :object_id => '1234', :changed_aspect => 'media'}]

    post '/image', nil, :input => Yajl.dump(events)
    assert_equal 'image!', @@service.messages.pop
    assert_equal 'by user! @ 09:18 PM link!', @@service.messages.pop
    assert_nil @@service.messages.pop
  end

  def test_searches_by_location
    @instagram.stubs.get("/v1/media/search.json?distance=1000&lat=lat&lng=lng&max_timestamp=&min_timestamp=") do
      stubbed_image
    end

    get "/search"
    assert_equal "caption! at location! by user! on Thu, Feb 03, 2011 @ 05:18 AM link!\nimage!", last_response.body
  end

  def test_responds_to_challenge
    get '/image', 'hub.challenge' => 'abc'
    assert_equal 'abc', last_response.body
  end

  def setup
    @@service.messages.clear
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
      :images   => {:standard_resolution => {:url => 'image!'}},
      :created_time => '1296710327'
    }.update(custom)])]
  end
end
