# This is designed to quickly launch the ChatGram app.  You can also manually
# require and configure the app yourself if you like.

require 'rubygems'
require 'bundler'
Bundler.setup
require File.expand_path("../lib/chat_gram/app", __FILE__)

# See http://instagr.am/developer/manage/
Instagram.configure do |c|
  # Your OAuth Client ID
  c.client_id = ENV['INSTAGRAM_ID']

  # Your OAuth Client Secret
  c.client_secret = ENV['INSTAGRAM_SECRET']

  # The access token of the Instagram user that fetches media content and
  # performs media searches.
  c.access_token = ENV['ACCESS_TOKEN']
end

ChatGram::App.set(
  # The detault latitude for media searches by location.
  :instagram_lat => ENV['INSTAGRAM_LAT'],

  # The detault longitude for media searches by location.
  :instagram_lng => ENV['INSTAGRAM_LNG'],

  # Allows you to specify a custom Instagram client instance.
  :instagram_client => nil,

  # Configures the chat service.
  :service => ChatGram::Service::Campfire.new(
    # The Campfire account subdomain.
    :domain => ENV['CAMPFIRE_DOMAIN'],

    # The token to authenticate with Campfire.
    :token => ENV['CAMPFIRE_TOKEN'],

    # The Campfire Room ID
    :room => ENV['CAMPFIRE_ROOM']),

  # Configures the data store.
  :model => ChatGram::Model::Database.new(
    # The URI of the database (automatically set by Heroku).
    :url => ENV['DATABASE_URL'])
  )
