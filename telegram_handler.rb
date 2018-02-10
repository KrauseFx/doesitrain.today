require 'telegram/bot'
require_relative "./database"

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
      self.create_user_if_doesnt_exist!(bot: bot, chat_id: message.chat.id)
    end

    if message.location
      current_user(chat_id: message.chat.id).update(
        lat: message.location.latitude,
        lng: message.location.longitude
      )
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
        bot.api.send_message(chat_id: message.chat.id, text: "Sorry, I didn't understand you")
      end
  end

  def self.current_user(chat_id: nil)
    return Database.database[:users].where(chat_id: chat_id)
  end

  def self.create_user_if_doesnt_exist!(bot: nil, chat_id: nil)
    return if current_user(chat_id: chat_id).count > 0

    Database.database[:users].insert({
      chat_id: chat_id,
      lat: nil,
      lng: nil
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
