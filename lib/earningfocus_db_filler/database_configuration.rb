require "active_record"

ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :host => "localhost",
  :database => "earningfocus",
  :username => "earningfocus",
  :password => ""
)