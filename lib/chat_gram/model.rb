module ChatGram
  # Defines the interface for the data model.
  class Model
    def initialize(options = {})
      raise NotImplementedError
    end

    def user_exists?(username)
      raise NotImplementedError
    end

    def approve(username, token)
      raise NotImplementedError
    end

    def insert(username, token = nil)
      raise NotImplementedError
    end

    def setup
    end

    require 'sequel'

    # Defines a class that stores users in a DB using the Sequel gem.  This
    # tracks the OAuth token for users, and makes sure only approved users
    # have their photos posted to the chat service.
    class Database
      attr_reader :db

      # Initializes a new Sequel connection.
      #
      # options - Options Hash:
      #           url - The String URI for the database server.
      #
      # Returns nothing.
      def initialize(options = {})
        @db = (url = options[:url]) ?
          Sequel.connect(url) :
          Sequel.sqlite
      end

      # Public: Checks to see if the user is approved to have their photos
      # posted.
      #
      # username - The String Instagram username.
      #
      # Returns true if the user is approved, or false.
      def approved?(username)
        return false if username.to_s.empty?

        user = @db[:users].where(:username => username).first
        user && !user[:token].to_s.empty?
      end

      # Public: Approves the given user and assigns their OAuth token.
      #
      # username - The String Instagram username.
      # token    - The String OAuth token.
      #
      # Returns true if the user is approved, or false.
      def approve(username, token)
        return false if username.to_s.empty? ||
          token.to_s.empty?

        num = @db[:users].
          where(:username => username).
          update(:token   => token)

        if num > 1
          raise "Multiple users named #{username.inspect}"
        else
          num == 1
        end
      end

      # Inserts the given user data into the db.
      #
      # username - The String Instagram username.
      # token    - the optional String OAuth token.
      #
      # Returns nothing.
      def insert(username, token = nil)
        @db[:users].insert :username => username, :token => token
      end

      # Lists all users.
      #
      # Returns an Array of Hashes.
      def users
        @db[:users].all
      end

      # Creates the database tables.
      #
      # Returns nothing.
      def setup
        @db.create_table :users do
          primary_key :id
          String :username, :unique => true, :null => false
          String :token
        end
      end
    end
  end
end
