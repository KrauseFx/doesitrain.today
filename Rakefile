require_relative './telegram_handler'
require_relative './weather'

task :hourly do
  Database.database[:users].each do |current_user|
    begin
      if current_user[:lat].nil? || current_user[:lng].nil?
        TelegramHandler.perform_with_bot do |bot|
          bot.api.send_message(
            chat_id: current_user[:chat_id],
            text: "Looks like you didn't send us your location yet, either share it using Telegram, or just type the city + country name here"
          )
        end
        next
      end

      puts "#{current_user[:hour_to_send]} != #{Time.now.hour}"
      next if current_user[:hour_to_send].to_i != Time.now.hour.to_i

      # Get the weather here
      rain = Weather.will_it_rain?(lat: current_user[:lat], lng: current_user[:lng])

      next unless rain # we only want to notify about rain, not about not rain

      TelegramHandler.perform_with_bot do |bot|
        bot.api.send_message(
          chat_id: current_user[:chat_id],
          text: "☔ It will probably rain today - bring an umbrella"
        )
      end
    rescue => ex
      puts ex.to_s
      puts(ex.backtrace.join("\n"))
    end
  end
end
