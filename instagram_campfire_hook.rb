require 'rubygems'
require 'bundler'
Bundler.require

class InstagramCampfireHookApp < Sinatra::Base
  set :instagram_http, Faraday::Connection.new("https://api.instagram.com/v1")
  set :campfire_http do
    url  = "https://#{ENV['CAMPFIRE_DOMAIN']}.campfirenow.com/room"
    conn = Faraday::Connection.new url do |b|
      b.request  :yajl
      b.adapter  :typhoeus
    end
    conn.basic_auth(ENV['CAMPFIRE_TOKEN'], 'X')
    conn
  end

  set :photo_room, ENV["CAMPFIRE_PHOTO"]
  set :debug_room, ENV["CAMPFIRE_DEBUG"]

  set :oauth, OAuth2::Client.new(ENV['INSTAGRAM_ID'], ENV['INSTAGRAM_SECRET'],
                                 :site => 'https://api.instagram.com/oauth/authorize')

  configure do
    DB = (url = ENV['DATABASE_URL']) ?
      Sequel.connect(url) :
      Sequel.sqlite
  end

  get '/' do
    'hwat'
  end

  get '/image' do
    params['hub.challenge'] || '\m/'
  end

  get '/search' do
    res = settings.instagram_http.get("media/search") do |req|
      req.params['client_id'] = settings.oauth.id
      req.params['client_secret'] = settings.oauth.secret
      req.params['lat']           = params[:lat] || '37.786937'
      req.params['lng']           = params[:lng] || '-122.398038'
      req.params['max_timestamp'] = params[:max]
      req.params['min_timestamp'] = params[:min]
    end
    images = Yajl.load(res.body)['data']
    image  = images[rand(images.size)]
    url    = image['images']['standard_resolution']['url']
    image_text(image) + "\n" + url
  end

  post '/image' do
    res=nil
    begin
      json = request.body.read
      data = Yajl.load(json)
      data.each do |payload|
        res  = settings.instagram_http.get("users/#{payload['object_id']}/media/recent") do |req|
          req.params['access_token'] = ENV['ACCESS_TOKEN']
        end

        display_image Yajl.load(res.body)['data'][0]
      end
      'ok'
    rescue Object => err
      speak settings.debug_room, res.body
      speak settings.debug_room, "#{err}\n  #{err.backtrace.join("\n  ")}"
      'nope'
    end
  end

  get '/auth' do
    redirect settings.oauth.web_server.authorize_url(
          :redirect_uri => callback_url,
          :scope => 'basic likes') + '&response_type=code'
  end

  get '/auth/callback' do
    user = nil
    begin
      api  = settings.oauth.web_server.
        get_access_token(params[:code],
                         :redirect_uri  => callback_url,
                         :response_type => 'code',
                         :grant_type    => 'authorization_code')
      user = settings.instagram_http.get('users/self') { |r| r.params['access_token'] = api.token }
      user = Yajl.load(user.body)
      num  = DB[:users].
        where(:username => user['data']['username']).
        update(:token => api.token)
      if num > 0
        '\m/'
      else
        "gtfo (ask hubot about #{user.inspect})"
      end
    rescue OAuth2::HTTPError => e
      speak settings.debug_room, e.response.inspect
      'oauth error (check debug room)'
    rescue Object => e
      speak settings.debug_room, user.inspect
      speak settings.debug_room, "#{e}\n  #{e.backtrace.join("\n  ")}"
      'big error (check debug room)'
    end
  end

  helpers do
    def speak(room, text)
      settings.campfire_http.post("#{room}/speak.json",
                                  :message => {:body => text})
    end

    def image_text(img)
      txt = if capt = img['caption']
        if loc = img['location']
          "#{capt['text']} at #{loc['name']}"
        else
          capt['text']
        end
      elsif loc = img['location']
        loc['name']
      end
      "%s by %s %s" % [
        txt,
        img['user']['username'],
        img['link']]
    end

    def display_image(img)
      url = img['images']['standard_resolution']['url']
      speak settings.photo_room, image_text(img).strip
      speak settings.photo_room, url
    end

    def callback_url
      uri = URI.parse(request.url)
      uri.path = '/auth/callback'
      uri.query = nil
      uri.to_s
    end
  end
end
