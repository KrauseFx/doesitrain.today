require 'telegram/bot'
require_relative "./database"
require_relative "./weather"

class TelegramHandler
  def self.listen
    self.perform_with_bot do |bot|
      bot.listen do |message|
        begin
          handle_message(bot, message)
        rescue => ex
          puts ex.to_s
          puts(ex.backtrace.join("\n"))
        end
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
      bot.api.send_message(chat_id: message.chat.id, 
            text: [
              "✅ Location received",
              "🕣 What time do you usually leave your house in the morning?"
            ].join("\n\n"))
      return 
    end

    # User wants to define the time they want to get the message
    if message.text.to_i > 0 || message.text == "0"
      hour_to_send = message.text.to_i

      if hour_to_send < 4 || hour_to_send > 11
        bot.api.send_message(chat_id: message.chat.id, 
          text: "💥 Sorry, please provide a time between 4am and 11am")
        return
      end

      u = current_user(chat_id: message.chat.id).first
      result = Weather.fetch_weather(location: "#{u[:lat]},#{u[:lng]}")
      location = (result || {})["location"]
      time_diff = ((Time.parse(location["localtime"]) - Time.now) / 60.0 / 60.0).round
      resulting_number = hour_to_send - time_diff - 1 # we want to warn the user **before** they leave the house
      resulting_number -= 24 if resulting_number >= 24

      current_user(chat_id: message.chat.id).update(
        hour_to_send: resulting_number
      )
      bot.api.send_message(chat_id: message.chat.id, 
          text: "✅ Nice! We'll send you a rain alert right before #{hour_to_send}am if it will rain today ☔️")
      return
    end

    case message.text
      when '/start'
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Hey #{message.chat.first_name} #{message.chat.last_name} 👋\n\nWelcome to @DoesItRainBot, never be surprised by rain again\n\nPlease either share your location, or enter your current city & country, so we can find the weather for you"
        )
      when '/stop'
        current_user(chat_id: message.chat.id).delete
        bot.api.send_message(chat_id: message.chat.id, text: "Sad to see you go. Just text me with `/start` to get started again. Byeeee")
      when '/stats'
        number_of_users = Database.database[:users].count
        bot.api.send_message(chat_id: message.chat.id, text: "Currently #{number_of_users} users use the @doesitrainbot (it's the best bot)")
      else
        location_txt = message.text
        result = Weather.fetch_weather(location: location_txt)
        location = (result || {})["location"]
        if location.nil? || location["lat"].nil?
          bot.api.send_message(chat_id: message.chat.id, 
            text: "💥 Sorry, I couldn't find a location named '#{location_txt}', please make sure to enter the city with correct spelling, or share your location using Telegram")
        else
          # Valid user input
          current_user(chat_id: message.chat.id).update(
            lat: location["lat"],
            lng: location["lon"] # lol `lon`
          )
          current_weather = result["current"]["condition"]["text"]
          country = location['country'].gsub("United States of America", "USA")
          bot.api.send_message(chat_id: message.chat.id, 
            text: [
              "✅ From now on, we're using #{location['name']} in #{country} for your rain alerts",
              "Current weather: #{current_weather}",
              "🕣 What time do you usually leave your house in the morning?"
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
