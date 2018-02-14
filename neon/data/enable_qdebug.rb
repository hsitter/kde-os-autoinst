#!/usr/bin/env ruby
#
# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
CONFIG

# FIXME: probably should rename this script to generic debug enablement
puts "#{$0} Adding systemd-coredump."
system 'apt update' || raise
system 'apt install -y systemd-coredump' || raise
