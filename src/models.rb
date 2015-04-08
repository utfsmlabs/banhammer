DataMapper::Logger.new($stdout, :debug)

if Cuba.settings[:production] == true
    #DataMapper.setup(:default, sqlite:)
elsif
    DataMapper.setup(:default, "sqlite://#{Dir.pwd}/testing.db")
end


class Ban
    include DataMapper::Resource

    property :id,   Serial
    property :username, String
    property :ban_date, DateTime, :default => DateTime.now
    property :ban_until, DateTime
    property :replacement_password, String
    property :current_password, String
    property :banned_by, String
    property :because, String
    property :unbanned, Boolean, :default => false
end

DataMapper.finalize

DataMapper.auto_upgrade!
