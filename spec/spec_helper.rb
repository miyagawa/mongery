require 'mongery'
require 'rspec'
require 'active_record'

RSpec.configure do |config|
  ActiveRecord::Base.establish_connection(
    adapter: 'postgresql',
    encoding: 'unicode',
    database: ENV['PG_DATABASE'],
    username: ENV['USER'],
    password: nil,
  )
end
