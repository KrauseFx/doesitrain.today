require_relative './telegram_handler'

task :morning do
  Database.database[:users].each do |current_user|
    TelegramHandler.perform_with_bot do |bot|
      bot.api.send_message(
        chat_id: current_user[:chat_id],
        text: "Hi there #{current_user[:lat]}"
      )
    end
  end
end
