#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'

TYPE = ENV.fetch('TYPE')
ISO_URL = "http://files.kde.org/neon/images/neon-#{TYPE}/current/neon-#{TYPE}-current.iso".freeze
ZSYNC_URL = "#{ISO_URL}.zsync".freeze
SIG_URL = "#{ISO_URL}.sig".freeze
GPG_KEY = '348C 8651 2066 33FD 983A 8FC4 DEAC EA00 075E 1D76'.freeze

if File.exist?('incoming.iso')
  warn "Using incoming.iso for #{TYPE}"
  FileUtils.mv('incoming.iso', 'neon.iso', verbose: true)
  exit 0
end

warn ISO_URL
if ENV['NODE_NAME'] # probably jenkins use, download from mirror
  # zsync_curl has severe performance problems from curl. It uses the same code
  # the original zsync but replaces the custom http with curl, the problem is
  # that the has 0 threading, so if only one block needs downloading it has
  # curl overhead + DNS overhead + SSL overhead + checksum single core calc.
  # All in all zsync_curl often performs vastly worse than downloading the
  # entire ISO would.
  # TODO: with this in place we can also drop stashing and unstashing of
  #   ISOs from master.
  system('wget', '-q', '-O', 'neon.iso',
         ISO_URL.gsub('files.kde.org', 'files.kde.mirror.pangea.pub')) || raise
else # probably not
  system('zsync_curl', '-o', 'neon.iso', ZSYNC_URL) || raise
end
system('wget', '-q', '-O', 'neon.iso.sig', SIG_URL) || raise
system('gpg2', '--recv-key', GPG_KEY) || raise
system('gpg2', '--verify', 'neon.iso.sig') || raise
