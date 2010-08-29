module NIDAG
  
  require 'nokogiri'
  require 'htmlentities'
  require 'yaml'
  require 'iconv'
  require 'active_record'
  require 'config'

  Dir["lib/*.rb"].each {|file| require file[/(.*)\.rb/,1] }
  
  VERSION = '0.0.1'
  
end