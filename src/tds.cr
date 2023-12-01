require "db"
require "./tds/**"

module TDS
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
end
