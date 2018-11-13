require 'telegram/bot'
require 'tempfile'
require_relative "./database"
require_relative "./weather"

class TelegramHandler
  def self.listen
    puts "Starting listening to Telegram messages..."

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
    if message.text.to_i > 0
      set_time(bot: bot, message: message)
      return
    end

    if message.text.start_with?("/start")
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Hey #{message.chat.first_name} #{message.chat.last_name} 👋\n\nWelcome to @DoesItRainBot, never be surprised by rain again\n\nPlease either share your location, or enter your current city & country, so we can find the weather for you\n\nEnter `/location city, country` or share your location using Telegram"
      )
    elsif message.text.start_with?("/stop")
      current_user(chat_id: message.chat.id).delete
        bot.api.send_message(chat_id: message.chat.id, text: "Sad to see you go. Just text me with `/start` to get started again. Byeeee")
    elsif message.text.start_with?("/stats")
      number_of_users = Database.database[:users].count
      show_map(message: message, bot: bot)
      bot.api.send_message(chat_id: message.chat.id, text: "Currently #{number_of_users} users use the @doesitrainbot")
    elsif message.text.start_with?("/location")
      if message.text.split(" ").count > 1
        set_weather(message: message, bot: bot)
      else
        bot.api.send_message(chat_id: message.chat.id, text: "Please use `/location City + Country`")
      end
    elsif message.text.start_with?("/time")
      if message.text.split(" ").count > 1
        set_time(bot: bot, message: message)
      else
        bot.api.send_message(chat_id: message.chat.id, text: "Please use `/time 8` (with `8` being the time you want to get the message for)")
      end
    elsif message.text.start_with?("/map")
      show_map(message: message, bot: bot)
    elsif message.text.downcase.include?("thank")
      bot.api.send_message(chat_id: message.chat.id, text: "Always here for you!")
    else
      text = [
        "Hey there, this bot is pretty basic so far, all I understand is:",
        "",
        "/start",
        "/location city, country - set the location",
        "/time 8 - set the time when you leave the apartment, full hours only",
        "/stats - get the numbers of active users of this bot",
        "/stop - quit using this bot",
        "",
        "Alternatively you can also send your location using the Telegram location button"
      ]
      bot.api.send_message(chat_id: message.chat.id, text: text.join("\n"))
      return
    end
  end

  def self.set_time(bot: nil, message: nil)
    raw_text = message.text.gsub("/time ", "")
    hour_to_send = raw_text.to_i

    if hour_to_send < 4 || hour_to_send > 11
      bot.api.send_message(chat_id: message.chat.id, 
        text: "💥 Sorry, please provide a time between 4am and 11am")
      return
    end

    u = current_user(chat_id: message.chat.id).first
    result = Weather.fetch_weather(location: "#{u[:lat]},#{u[:lng]}")
    location = (result || {})["location"]
    timezone = (location || {})["tz_id"]

    current_user(chat_id: message.chat.id).update(
      hour_to_send: hour_to_send - 1, # we want to warn the user **before** they leave the house
      timezone: timezone
    )
    bot.api.send_message(chat_id: message.chat.id, 
        text: "✅ Nice! We'll send you a rain alert right before #{hour_to_send}am if it will rain that day ☔️")
  end

  def self.show_map(message: nil, bot: nil)
    file = Tempfile.new("graph")
    file_path = "#{file.path}.png"

    google_url = "https://maps.googleapis.com/maps/api/staticmap?center=Spain&size=640x300&scale=2&maptype=roadmap&zoom=1"
    all_markers = Database.database[:users].all.keep_if{|u|!u[:lat].nil?}.collect{ |u| "#{u[:lat].round(2)},#{u[:lng].round(2)}" }.join("%7C")
    markers = "&markers=#{all_markers}"
    key = "&key=#{ENV['GOOGLE_MAPS_API_KEY']}"
    full_url = [google_url, markers, key].join("")
    puts full_url
    File.write(file_path, open(full_url).read)
    bot.api.send_photo(
      chat_id: message.chat.id, 
      photo: Faraday::UploadIO.new(file_path, 'image/png')
    )
  end

  def self.set_weather(bot: nil, message: nil)
    location_txt = message.text.gsub("/location ", "")
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
