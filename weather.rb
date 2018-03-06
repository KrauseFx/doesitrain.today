require 'open-uri'
require 'json'

class Weather
  def self.fetch_weather(location: nil)
    api_key = ENV["WEATHER_API_KEY"]
    url = "https://api.apixu.com/v1/forecast.json?key=#{api_key}&q=#{location}"
    puts url
    return JSON.parse(open(url).read)
  rescue
    nil
  end

  def self.will_it_rain?(lat: nil, lng: nil)
    result = self.fetch_weather(location: "#{lat},#{lng}")
    if result && result["current"]
      today = result["current"]
      self.rain_conditions.each do |current_condition|
        return true if today["condition"]["text"].downcase.include?(current_condition)
      end
    end
    return false
  end

  def self.rain_conditions
    [
      "rain",
      "drizzle",
      "snow",
      "shower",
      "ice",
      "thunder"
    ]
  end
end
