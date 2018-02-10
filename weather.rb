require 'open-uri'
require 'json'

class Weather
  def self.fetch_weather(lat: nil, lng: nil)
    api_key = ENV["WEATHER_API_KEY"]
    search_str = "#{lat},#{lng}"
    url = "https://api.apixu.com/v1/forecast.json?key=#{api_key}&q=#{search_str}"
    return JSON.parse(open(url).read)
  end

  def self.will_it_rain?(lat: nil, lng: nil)
    result = self.fetch_weather(lat: lat, lng: lng)
    if result && result["current"]
      today = result["current"]
      return today["condition"]["text"].downcase.include?("rain")
    end
    return nil
  end
end
