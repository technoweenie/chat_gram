require 'rubygems'
require 'bundler'
Bundler.setup

require File.expand_path("../lib/chat_gram", __FILE__)

model = ChatGram::Model::Database.new(:url => ENV['DATABASE_URL'])

desc "Sets up the Model data store"
task :setup do
  model.setup
end

desc "Adds a user to the data store.  U=username"
task :add do
  model.insert ENV['U']
end

desc "Lists all users, and whether they are approved (\m/) or not."
task :list do
  model.users.each do |user|
    puts "#{user[:username]} #{user[:token] ? '\m/' : ':('}"
  end
end

desc "Dumps the user data."
task :dump do
  puts model.users
end
