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

ISO_URL = 'http://files.kde.org/neon/images/neon-useredition/current/neon-useredition-current.iso.zsync'.freeze
SIG_URL = 'http://files.kde.org/neon/images/neon-useredition/current/neon-useredition-current.iso.sig'.freeze
GPG_KEY = '348C 8651 2066 33FD 983A 8FC4 DEAC EA00 075E 1D76'.freeze

system('sudo apt-get -y install git devscripts autotools-dev libcurl4-openssl-dev') || raise
system('git clone https://github.com/AppImage/zsync-curl.git') unless File.exist?('zsync-curl')
system('./zsync-curl/build.sh') || raise

system('/usr/local/bin/zsync_curl', '-q', '-o', 'neon.iso', ISO_URL) || raise
system('wget', '-q', '-O', 'neon.iso.sig', SIG_URL) || raise
system('gpg2', '--recv-key', GPG_KEY) || raise
system('gpg2', '--verify', 'neon.iso.sig') || raise