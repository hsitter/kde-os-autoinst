#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2017-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

require 'fileutils'

puts "#{$0} Enabling Qt Logging."

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
qt.qpa.input.events=false
qt.qpa.events=false
qt.v4.asm=false
CONFIG
