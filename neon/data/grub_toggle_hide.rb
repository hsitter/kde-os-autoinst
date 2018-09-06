#!/usr/bin/env ruby
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

# Forces grub to unhide.

cfgfile = '/etc/default/grub'
backupfile = "#{cfgfile}.hidden"

def update_grub
  return if system('update-grub')
  raise 'Failed to update-grub'
end

if File.exist?(backupfile)
  puts "Restoring backup file #{backupfile}"
  update_grub
  exit 0
end

unless File.exist?(cfgfile)
  puts "Config file #{cfgfile} not found, assumbing unhidden."
  exit 0
end

data = File.read(cfgfile)
File.write(backupfile, data) # safe a backup

# Force style menu (as opposed to hidden), this should in theory override any
# other hidden setting and always use menu. To be on the safe side we'll mangle
# the config a bit more though.
data.gsub!(/^GRUB_TIMEOUT_STYLE=.+/, 'GRUB_TIMEOUT_STYLE=menu')
data << "\nGRUB_TIMEOUT_STYLE=menu\n" unless data.include?('GRUB_TIMEOUT_STYLE')
# Disable the hidden timeout entirely.
data.gsub!(/^GRUB_HIDDEN_TIMEOUT=.+/, '')
# But just in case grub decides to ignore this, also force it to not be quiet.
data.gsub!(/^GRUB_HIDDEN_TIMEOUT_QUIET=.+/, 'GRUB_HIDDEN_TIMEOUT_QUIET=false')
# Set a reasonably high visible timeout so we can definitely screenshot it.
data.gsub!(/^GRUB_TIMEOUT=.+/, 'GRUB_TIMEOUT=10')
# Ditch serial setup in case the ISO was running with a console= argument which
# may have been used for debugging reboot problems.
data.gsub!(/^GRUB_TERMINAL=.+/, '')
data.gsub!(/^GRUB_SERIAL_COMMAND=.+/, '')

File.write(cfgfile, data)

# Log it to screen.
puts cfgfile
puts File.read(cfgfile)

update_grub
exit 0
