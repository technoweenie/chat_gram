# This is designed to quickly launch the ChatGram app.  You can also manually
# require and configure the app yourself if you like.

require 'rubygems'
require 'bundler'
Bundler.setup
require File.expand_path("../lib/chat_gram/app", __FILE__)

Instagram.configure do |c|
  c.client_id     = ENV['INSTAGRAM_ID']
  c.client_secret = ENV['INSTAGRAM_SECRET']
  c.access_token  = ENV['ACCESS_TOKEN']
end

ChatGram::App.set \
  :instagram_lat    => ENV['INSTAGRAM_LAT'],
  :instagram_lng    => ENV['INSTAGRAM_LNG'],
  :instagram_client => nil,
  :service => ChatGram::Service::Campfire.new(
    :domain => ENV['CAMPFIRE_DOMAIN'],
    :token  => ENV['CAMPFIRE_TOKEN'],
    :room   => ENV['CAMPFIRE_ROOM']),
  :model => ChatGram::Model::Database.new(
    :url => ENV['DATABASE_URL'])
