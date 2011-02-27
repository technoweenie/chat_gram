require 'rubygems'
require 'bundler'
Bundler.require

class InstagramCampfireHookApp < Sinatra::Base
  set :instagram_lat  => ENV['INSTAGRAM_LAT'],
      :instagram_lng  => ENV['INSTAGRAM_LNG']

  set :campfire_http do
    url  = "https://#{ENV['CAMPFIRE_DOMAIN']}.campfirenow.com/room"
    conn = Faraday.new url do |b|
      b.request  :yajl
      b.adapter  :typhoeus
    end
    conn.basic_auth(ENV['CAMPFIRE_TOKEN'], 'X')
    conn
  end

  set :photo_room => ENV["CAMPFIRE_PHOTO"],
      :debug_room => ENV["CAMPFIRE_DEBUG"]

  configure do
    DB = (url = ENV['DATABASE_URL']) ?
      Sequel.connect(url) :
      Sequel.sqlite

    Instagram.configure do |c|
      c.client_id     = ENV['INSTAGRAM_ID']
      c.client_secret = ENV['INSTAGRAM_SECRET']
      c.adapter       = :typhoeus
    end
  end

  before do
    @instagram = settings.instagram_client || Instagram.client
  end

  get '/' do
    'hwat'
  end

  get '/image' do
    params['hub.challenge'] || '\m/'
  end

  get '/search' do
    images = @instagram.media_search \
      params[:lat] || settings.instagram_lat,
      params[:lng] || settings.instagram_lng,
      :max_timestamp => params[:max],
      :min_timestamp => params[:min]

    image  = images[rand(images.size)]
    url    = image.images.standard_resolution.url
    image_text(image) + "\n" + url
  end

  post '/image' do
    res=nil
    begin
      json = request.body.read
      data = Yajl.load(json)
      data.each do |payload|
        images = @instagram.user_recent_media payload['object_id'],
                   :access_token => ENV['ACCESS_TOKEN']
        display_image images.first
      end
      'ok'
    rescue Object => err
      speak settings.debug_room, res.body if res
      speak settings.debug_room, "#{err}\n  #{err.backtrace.join("\n  ")}"
      'nope'
    end
  end

  get '/auth' do
    redirect @instagram.authorize_url \
          :redirect_uri => callback_url,
          :scope => 'basic likes'
  end

  get '/auth/callback' do
    user = nil
    begin
      api = @instagram.get_access_token params[:code],
                                        :redirect_uri => callback_url

      user = @instagram.user :access_token => api.access_token
      num  = DB[:users].
        where(:username => user.username).
        update(:token => api.access_token)
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
      txt = if capt = img.caption
        if loc = img.location
          "#{capt.text} at #{loc.name}"
        else
          capt.text
        end
      elsif loc = img.location
        loc.name
      end
      "%s by %s %s" % [txt, img.user.username, img.link]
    end

    def display_image(img)
      url = img.images.standard_resolution.url
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
