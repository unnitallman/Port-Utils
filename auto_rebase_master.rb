require 'octokit'

puts "Hello world"

client = Octokit::Client.new(:access_token => ENV["AUTOREBASE_TOKEN"])
puts client.user.name
