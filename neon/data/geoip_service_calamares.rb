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

# Doubles our geoip service so we get consistent results

require 'json'
require 'webrick'
require 'yaml'

server = WEBrick::HTTPServer.new(Port: 0)

conf = '/etc/calamares/modules/locale.conf'
abort "Couldn't find config #{conf}" unless File.exist?(conf)
yaml = YAML.load_file(conf)
yaml['geoipUrl'] = "http://localhost:#{server.config[:Port]}"
File.write(conf, YAML.dump(yaml))

server.mount_proc '/' do |_req, res|
  # Format as documented in calamares' locale.conf. This is a test double
  # for geoip.kde.org.
  #
  # We are using a fancy time zone here to make sure calamares handles three
  # level timezones correctly.
  # Additionally calamares derives language and keyboard layout from the
  # timezone, so something en_US is preferred so we don't have to handle l10n.
  # A dedicated l10n test would have to do that, but for the purpose of the
  # core testing we stick to en_US.
  res.body = JSON.generate('time_zone' => 'America/North_Dakota/Beulah')
end

server.start
