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

# Mock Ubuntu's geoip service so we get consistent results
# for Frankfurt; Timezone Berlin.

require 'webrick'

server = WEBrick::HTTPServer.new(Port: 0)
unless system('debconf-set',
              'tzsetup/geoip_server',
              "http://localhost:#{server.config[:Port]}")
  raise 'failed to override geoip server via debconf'
end

server.mount_proc '/' do |_req, res|
  res.body = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Ip>46.101.149.170</Ip>
  <Status>OK</Status>
  <CountryCode>DE</CountryCode>
  <CountryCode3>DEU</CountryCode3>
  <CountryName>Germany</CountryName>
  <RegionCode>05</RegionCode>
  <RegionName>Hessen</RegionName>
  <City>Frankfurt</City>
  <ZipPostalCode>09228</ZipPostalCode>
  <Latitude>50.1167</Latitude>
  <Longitude>8.6833</Longitude>
  <AreaCode>0</AreaCode>
  <TimeZone>Europe/Berlin</TimeZone>
</Response>
  XML
end

server.start
