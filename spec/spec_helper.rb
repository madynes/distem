require 'distem'
require 'distem/resource/alevingraphviz'

def random_string(maxsize = 8)
  chars = [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
  size = rand(maxsize)
  return (0..size).map{ chars[rand(chars.length)] }.join
end
