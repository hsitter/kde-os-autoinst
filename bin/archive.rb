#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require 'tty/command'

OPENQA_SERIES = ENV.fetch('OPENQA_SERIES', 'xenial')
TYPE = ENV.fetch('TYPE')
# Both rsync and tar have the same exclude arg syntax \o/
EXCLUSION_ARGS = %w[
  --exclude=*.iso
  --exclude=*.iso.*
  --exclude=*socket
  --exclude=wok/video.ogv
  --exclude=wok/ulogs
  --exclude=wok/testresults
].freeze

cmd = TTY::Command.new

# Master
if ENV.fetch('NODE_NAME') == 'master'
  tar = "/var/www/metadata/os-autoinst/#{TYPE}.tar"
  cmd.run('tar', *EXCLUSION_ARGS, '-cf', "#{tar}.new" '.')
  cmd.run("mv -v #{tar}.new #{tar}")
  exit
end

# else we are on an openqa slave, so use a flatter layout for speedy use.
# TODO: ideally we should only publish the raid itself and expect tests to clone
#   the git repo

destdir = "/srv/os-autoinst/#{OPENQA_SERIES}/#{TYPE}"
FileUtils.mkpath(destdir) unless File.exist?(destdir)
cmd.run('rsync', '-a', '--delete', '--info=progress2',
        *EXCLUSION_ARGS,
        './', destdir)
