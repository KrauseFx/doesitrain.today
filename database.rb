require "sequel"

class Database
  def self.database
    @_db ||= Sequel.connect(ENV["DATABASE_URL"])

    unless @_db.table_exists?("users")
      @_db.create_table :users do
        primary_key :id
        Integer :chat_id
        Float :lat
        Float :lng
      end
    end

    return @_db
  end
end
