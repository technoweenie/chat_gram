require 'rubygems'
require 'bundler'
Bundler.require

DB = (url = ENV['DATABASE_URL']) ?
  Sequel.connect(url) :
  Sequel.sqlite

task :create do
  DB.create_table :users do
    primary_key :id
    String :username, :unique => true, :null => false
    String :token
  end
end

task :add do
  DB[:users].insert :username => ENV['U']
end

task :list do
  DB[:users].each do |user|
    puts "#{user[:username]} #{user[:token] ? '\m/' : ':('}"
  end
end
