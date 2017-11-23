#!/usr/bin/env ruby

puts "#{$0}: Checking permission of sudo"
stat = File.stat('/usr/bin/sudo')
unless stat.uid.zero?
  warn "#{$0}: User #{stat.uid} owns sudo!"
  exit 1
end
