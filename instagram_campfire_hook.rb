require 'rubygems'
require 'bundler'
Bundler.require

Instagram.configure do |c|
  c.client_id     = ENV['INSTAGRAM_ID']
  c.client_secret = ENV['INSTAGRAM_SECRET']
  c.access_token  = ENV['ACCESS_TOKEN']
end

DB = (url = ENV['DATABASE_URL']) ?
  Sequel.connect(url) :
  Sequel.sqlite

class InstagramCampfireHookApp < Sinatra::Base
  set :instagram_lat    => ENV['INSTAGRAM_LAT'],
      :instagram_lng    => ENV['INSTAGRAM_LNG'],
      :instagram_client => nil

  set :campfire_http do
    url  = "https://#{ENV['CAMPFIRE_DOMAIN']}.campfirenow.com/room"
    conn = Faraday.new url do |b|
      b.request  :yajl
      b.adapter  :excon
    end
    conn.basic_auth(ENV['CAMPFIRE_TOKEN'], 'X')
    conn
  end

  set :campfire_room => ENV["CAMPFIRE_ROOM"]

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
        images = @instagram.user_recent_media payload['object_id']
        image  = images.first
        if DB[:users].where(:username => image.user.username).count.zero?
          puts "#{image.user.username} is not authorized for campfire"
        else
          display_image image
        end
      end
      'ok'
    rescue Object => err
      puts res.body.inspect if res
      raise
    end
  end

  get '/auth' do
    redirect @instagram.authorize_url \
          :redirect_uri => callback_url,
          :scope => 'basic likes'
  end

  get '/auth/callback' do
    res = nil
    begin
      data = @instagram.get_access_token params[:code],
                                         :redirect_uri => callback_url
      DB[:users].
        where(:username => data.user.username).
        update(:token => data.access_token)
      '\m/'
    rescue Object => e
      puts res.inspect
      raise
    end
  end

  helpers do
    def speak(text)
      settings.campfire_http.post("#{settings.campfire_room}/speak.json",
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
      now  = Time.now
      time = Time.at(img.created_time.to_i)
      ts   = ''
      if !(time.year == now.year && time.month == now.month && time.day == now.day)
        ts << time.strftime("on %a, %b %d, %Y ")
      end
      ts << time.strftime("@ %I:%M %p")

      "%s by %s %s %s" % [txt, img.user.username, ts, img.link]
    end

    def display_image(img)
      url = img.images.standard_resolution.url
      speak image_text(img).strip
      speak url
    end

    def callback_url
      uri = URI.parse(request.url)
      uri.path = '/auth/callback'
      uri.query = nil
      uri.to_s
    end
  end
end
