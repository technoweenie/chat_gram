%w(model service).each do |lib|
  require File.expand_path("../chat_gram/#{lib}", __FILE__)
end

module ChatGram
  VERSION = '0.5.0'
end
