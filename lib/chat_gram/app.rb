require File.expand_path('../../chat_gram', __FILE__)
require 'instagram'
require 'sinatra/base'
require 'mustache/sinatra'

module ChatGram
  class App < Sinatra::Base
    register Mustache::Sinatra
    enable :sessions

    root_dir = File.expand_path('..', __FILE__)
    set :mustache, {
      :views     => "#{root_dir}/views/",
      :templates => "#{root_dir}/templates/"
    }

    module Views
    end

    before do
      @instagram = settings.instagram_client || Instagram.client
    end

    # lol homepage
    get '/' do
      "hwat (#{session[:login].inspect})"
    end

    # List the existing users that have their Instagram photos posted to
    # the chat service.  Unapproved logins are those that have not authorized
    # with Instgram yet.
    get "/users" do
      if settings.model.approved?(session[:login])
        @users = settings.model.users
        mustache :users
      else
        redirect "/auth"
      end
    end

    post "/users" do
      settings.model.insert(params[:username])
      redirect "/users"
    end

    delete '/users/:username' do
      settings.model.remove params[:username]
      'ok'
    end

    # This is the endpoint to provide start the OAuth authorization process.
    #
    # See http://instagram.com/developer/auth/
    get '/auth' do
      redirect @instagram.authorize_url \
            :redirect_uri => callback_url,
            :scope => 'basic likes'
    end

    # This is the OAuth callback. This should store the user's token.
    #
    # See http://instagram.com/developer/auth/
    get '/auth/callback' do
      res = nil
      begin
        data = @instagram.get_access_token params[:code],
                                           :redirect_uri => callback_url

        if settings.model.approve(data.user.username, data.access_token)
          session[:login] = data.user.username
          redirect "/users"
        else
          "You're not on the list.  Get someone to add you to #{absolute_url("/auth")}."
        end
      rescue Object => e
        puts res.inspect
        raise
      end
    end

    # Simple text-based search, designed for a chat bot to insert into the
    # chat stream.
    #
    # Example:
    #
    #     rick:  hubot: instagram near indio, CA
    #     hubot: SUBJECT at LOCATION by USER @ TIME INSTAGRAM-URL
    get '/search' do
      images = @instagram.media_search \
        params[:lat] || settings.instagram_lat,
        params[:lng] || settings.instagram_lng,
        :max_timestamp => params[:max],
        :min_timestamp => params[:min],
        :distance      => params[:distance] || '1000'

      if image = images[rand(images.size)]
        url = image.images.standard_resolution.url
        image_text(image) + "\n" + url
      else
        "empty search!"
      end
    end

    # This is the actual realtime webhook from Instagram.  See the "Receiving
    # Updates" area on http://instagram.com/developer/realtime/.
    post '/image' do
      res=nil
      begin
        json = request.body.read
        data = Yajl.load(json)
        data.each do |payload|
          images = @instagram.user_recent_media payload['object_id']
          image  = images.first
          if settings.model.approved?(image.user.username)
            display_image image
          else
            puts "#{image.user.username} is not authorized for campfire"
          end
        end
        'ok'
      rescue Object => err
        puts res.body.inspect if res
        raise
      end
    end

    # This verifies the Instagram pubsub webhook.  After creating an Instagram
    # subscription, they will contact this site.  You will need to repeat
    # the challenge so that Instagram will trust this webhook.
    #
    # See http://instagram.com/developer/realtime/ for details.
    get '/image' do
      params['hub.challenge'] || '\m/'
    end

    helpers do
      # Public: Sends the given sentences to the chat service.
      #
      # sentences - One or more Strings.
      #
      # Returns nothing.
      def speak(*sentences)
        sentences.each do |text|
          settings.service.speak(text)
        end
      end

      # Public: Generates the text sent to the chat services for a given image
      # object.
      #
      # img - A Hashie instance of the JSON image data.  See the 'data' field
      #       from http://instagram.com/developer/endpoints/media/
      #
      # Returns the String message.
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

      # Public: Sends the Instagram Media info to the chat service.
      #
      # img - A Hashie instance of the JSON image data.  See the 'data' field
      #       from http://instagram.com/developer/endpoints/media/
      #
      # Returns nothing.
      def display_image(img)
        url = img.images.standard_resolution.url
        speak image_text(img).strip, url
      end

      # Generates the OAuth callback URL for this web server by looking at the
      # request URL.
      #
      # Returns a String URL.
      def callback_url
        absolute_url("/auth/callback")
      end

      def absolute_url(path)
        uri = URI.parse(request.url)
        uri.path = path
        uri.query = nil
        uri.to_s
      end
    end
  end
end
