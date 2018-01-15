#!/usr/bin/env ruby
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

# Generic setup helper for basetests.
# In here you should do all things that make sense for all tests as default
# behavior (certain tests can still opt out by undoing whatever is done etc).
# This is all in one file to speed things up. Running invidiual commands is
# slower in os-autoinst, and since this all counts as the same script...

puts "#{$0}: Upgrading to bionic via apt..."

ENV['DEBIAN_FRONTEND'] = 'noninteractive'

sources = Dir.glob('/etc/apt/sources.list.d/*') << '/etc/apt/sources.list'
sources.each do |source|
  data = File.read(source)
  data = data.gsub('xenial', 'bionic')
  data = data.gsub('/user', '/dev/unstable')
  data = data.gsub('/release', '/dev/unstable')
  File.write(source, data)
end

system('apt update') || raise

puts "#{$0}: ... running a simultation before the real deal ..."
system('apt dist-upgrade -y -s 2>&1 | tee /tmp/simulation.txt') || raise

puts "#{$0}: ... and for real now ..."
system('apt dist-upgrade') || raise
