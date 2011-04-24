module ChatGram
  # Defines the simple API that all chat services should honor.
  class Service
    def initialize(options = {})
      raise NotImplementedError
    end

    def speak(text)
      raise NotImplementedError
    end

    require 'faraday'

    # This is a class that knows how to speak in a Campfire channel.
    class Campfire
      # Sets up an HTTP client with the following Campfire options.
      #
      # options - Hash of options:
      #           domain - The String subdomain of the Campfire account.
      #           room   - The String Campfire Room ID.
      #           token  - The String token for the Campfire account.
      #
      # Returns nothing.
      def initialize(options = {})
        url  = "https://%s.campfirenow.com/room/%s" % [
          options[:domain],
          options[:room]]
        @conn = Faraday.new url do |b|
          b.request :yajl
          b.adapter :excon
        end
        @conn.basic_auth options[:token], 'X'
      end

      # Public: Posts the given message to the Campfire room.
      #
      # text - The String message to be sent to the chat room.
      #
      # Returns nothing.
      def speak(text)
        @conn.post 'speak.json', :message => {:body => text}
      end
    end
  end
end
