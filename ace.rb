require 'nidag'
include NIDAG

# Initialize database connection
ActiveRecord::Base.establish_connection(
  :adapter => "mysql",
  :host => DB_HOST,
  :username => DB_USERNAME,
  :password => DB_PASSWORD,
  :database => DB_DATABASE) 

# Scan content directory and update DB
Processor.parse_content