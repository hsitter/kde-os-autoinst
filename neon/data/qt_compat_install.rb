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

puts "#{$0}: Installing Qt compatibility check packages..."

ENV['DEBIAN_FRONTEND'] = 'noninteractive'

system('apt update') || raise
system('apt dist-upgrade -y') || raise
system('apt', 'install', '-y', *ARGV) || raise
