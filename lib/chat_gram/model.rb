module ChatGram
  # Defines the interface for the data model.
  class Model
    def initialize(options = {})
      raise NotImplementedError
    end

    # Public: Checks to see if the user is registered.
    #
    # username - The String Instagram username.
    #
    # Returns true if the user exists, or false.
    def exists?(username)
      find(username) ? true : false
    end

    # Public: Checks to see if the user is approved to have their photos
    # posted.
    #
    # username - The String Instagram username.
    #
    # Returns true if the user is approved, or false.
    def approved?(username)
      if user = find(username)
        !user[:token].to_s.empty?
      else
        false
      end
    end

    def find(username)
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
    class Database < Model
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

      # Public: Finds the user record.
      #
      # username - The String Instagram username.
      #
      # Returns a Hash of the user attributes, or nil.
      def find(username)
        return if username.to_s.empty?
        @db[:users].where(:username => username).first
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

      # Public: Inserts the given user data into the db.
      #
      # username - The String Instagram username.
      # token    - the optional String OAuth token.
      #
      # Returns false if the username is blank, or true.
      def insert(username, token = nil)
        return false if username.to_s.empty?
        @db[:users].insert :username => username, :token => token
      rescue Sequel::DatabaseError
        false
      end

      # Public: Removes the user from the db.
      #
      # username - The String Instagram username.
      #
      # Returns false if the username is blank, or true.
      def remove(username)
        return false if username.to_s.empty?
        @db[:users].where(:username => username).delete && true
      rescue Sequel::DatabaseError
        false
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
