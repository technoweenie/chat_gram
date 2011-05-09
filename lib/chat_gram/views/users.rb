module ChatGram
  class App
    module Views
      class Users < Mustache
        def users
          @users.each do |u|
            u[:css_class] = u[:token].to_s.empty? ?
              :unauthorized : :authorized
          end
        end
      end
    end
  end
end
