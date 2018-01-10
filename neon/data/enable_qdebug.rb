#!/usr/bin/env ruby

require 'fileutils'

puts "#{$0} Enablging Qt Logging."

dir = "/home/#{ENV.fetch('USER')}/.config/QtProject/"
FileUtils.mkpath(dir)
File.write("#{dir}/qtlogging.ini", <<-CONFIG)
[Rules]
*=true
kf5.kcoreaddons.desktopparser=false
org.kde.plasma.pulseaudio=false
qt.scenegraph.renderloop=false
qt.scenegraph.time.*=false
qt.quick.dirty=false
qt.quick.hover.trace=false
CONFIG
