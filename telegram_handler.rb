require 'telegram/bot'
require_relative "./database"
require_relative "./weather"

class TelegramHandler
  def self.listen
    self.perform_with_bot do |bot|
      bot.listen do |message|
        handle_message(bot, message)
      end
    end
  end

  def self.handle_message(bot, message)
    if message.text != "/stop"
      self.create_user_if_doesnt_exist!(bot: bot, message: message)
    end

    if message.location
      current_user(chat_id: message.chat.id).update(
        lat: message.location.latitude,
        lng: message.location.longitude
      )
      return 
    end

    # User wants to define the time they want to get the message
    if message.text.to_i > 0 || message.text == "0"
      hour_to_send = message.text.to_i

      if hour_to_send < 4 || hour_to_send > 11
        # bot.api.send_message(chat_id: message.chat.id, 
        #   text: "💥 Sorry, please provide a time between 4am and 11am")
        # return
      end

      u = current_user(chat_id: message.chat.id).first
      result = Weather.fetch_weather(location: "#{u[:lat]},#{u[:lng]}")
      location = (result || {})["location"]
      time_diff = ((Time.parse(location["localtime"]) - Time.now) / 60.0 / 60.0).round

      current_user(chat_id: message.chat.id).update(
        hour_to_send: hour_to_send - time_diff
      )
      bot.api.send_message(chat_id: message.chat.id, 
          text: "🕐 Nice, from now on we'll send you the weather report at #{hour_to_send} in your time zone")
      return
    end

    case message.text
      when '/start'
        # already handled
      when '/stop'
        current_user(chat_id: message.chat.id).delete
        bot.api.send_message(chat_id: message.chat.id, text: "Sad to see you go. Just text me with `/start` to get started again. Byeeee")
      else
        location = message.text
        result = Weather.fetch_weather(location: location)
        location = (result || {})["location"]
        if location.nil? || location["lat"].nil?
          bot.api.send_message(chat_id: message.chat.id, 
            text: "💥 Sorry, I couldn't find a location named '#{location}', please make sure to enter the city with correct spelling, or share your location using Telegram")
        else
          # Valid user input
          current_user(chat_id: message.chat.id).update(
            lat: location["lat"],
            lng: location["lon"] # lol `lon`
          )
          current_weather = result["current"]["condition"]["text"]
          bot.api.send_message(chat_id: message.chat.id, 
            text: [
              "✅ Success! From now on, we're using #{location['name']} in #{location['country']} for your weather reports",
              "Current weather: #{current_weather}",
              "You're all set, we'll message you in the morning of each day if it will rain today"
            ].join("\n\n"))
        end
      end
  end

  def self.current_user(chat_id: nil)
    return Database.database[:users].where(chat_id: chat_id)
  end

  def self.create_user_if_doesnt_exist!(bot: nil, message: nil)
    chat_id = message.chat.id
    return if current_user(chat_id: chat_id).count > 0

    Database.database[:users].insert({
      chat_id: chat_id,
      lat: nil,
      lng: nil,
      hour_to_send: 8
    })

    bot.api.send_message(
      chat_id: chat_id,
      text: "Hey #{message.chat.first_name} #{message.chat.last_name} 👋\n\nPlease either share your location, or enter your current city & country"
    )
  end

  def self.perform_with_bot
    # https://github.com/atipugin/telegram-bot-ruby
    yield self.client
  rescue => ex
    puts "error sending the telegram notification"
    puts ex
    puts ex.backtrace
  end

  def self.token
    ENV["TELEGRAM_TOKEN"]
  end

  def self.client
    return @client if @client
    raise "No Telegram token provided on `TELEGRAM_TOKEN`" if token.to_s.length == 0
    @client = ::Telegram::Bot::Client.new(token)
  end
end
