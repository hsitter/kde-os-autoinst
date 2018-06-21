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

# Install all packages in the neon repo.
# This is somewhat overlappingly duplicative of pangea-tooling's
# repo_abstraction, but we don't have access to the tooling inside the VM, and
# considering the use case its tech is vastly too advanced and hard to use.

begin
  require 'aptly'
rescue LoadError
  raise 'not root' if Process.uid != 0
  Gem.install('aptly-api')
  require 'aptly'
end

Aptly.configure do |config|
  config.uri = URI::HTTPS.build(host: 'archive-api.neon.kde.org')
end

sources = File.read('/etc/apt/sources.list.d/neon.list')
sources = sources.split($/).reject { |x| x.start_with?('#') || x.empty? }
sources = sources.compact.uniq
source = sources[0]
warn "Source: #{source}"
raise source unless source.start_with?('deb http://archive.neon')
parts = source.split(' ')
source_uri = URI.parse(parts[1])
dist = parts[2]

pub = Aptly::PublishedRepository.list.find do |x|
  File.join('/', x.Prefix) == source_uri.path && x.Distribution == dist
end
packages = []
pub.Sources.each do |x|
  packages += x.packages(q: '!Name (~ ".*-[dbg|dbgsym]"), $Architecture (amd64)')
end
packages = packages.collect { |x| x.split(' ')[1] }
# special hack, neon-adwaita in 16.04 is not meant to be installed
EXCLUSIONS = %w[neon-adwaita].freeze
packages = packages.reject { |x| EXCLUSIONS.include?(x) }

# TODO: remove. this is a temporary workaround for calmares-settings not
#   properly cleaning up after the original installation from the ISO
# https://packaging.neon.kde.org/neon/calamares-settings.git/commit/?h=Neon/unstable&id=245ad665fda23043e7220cc480ff8afd24c3dc32
FileUtils.rm_f('/usr/bin/_neon.calamares')

ENV['DEBIAN_FRONTEND'] = 'noninteractive'
system('apt update') || raise
system('apt', 'install', '-y', *packages) || raise
