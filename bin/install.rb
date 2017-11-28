#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

require 'mkmf' # for find_executable

build_deps = %w[libtheora-dev libopencv-dev libfftw3-dev libsndfile1-dev
                pkg-config libtool autoconf automake build-essential
                libxml2-dev libssh2-1-dev libdbus-1-dev carton]
runtime_deps = %w[kvm qemu kmod git ovmf]
zsync_build_deps = %w[devscripts autotools-dev libcurl4-openssl-dev]
deps = build_deps + runtime_deps + zsync_build_deps

system("apt install --no-install-recommends -y #{deps.join(' ')}") || raise

unless find_executable('zsync_curl')
  puts 'installing zsync_curl'
  if File.exist?('zsync-curl')
    system('git pull --rebase', chdir: 'zsync-curl')
  else
    system('git clone https://github.com/AppImage/zsync-curl.git') || raise
  end
  system('./zsync-curl/build.sh') || raise
end

unless File.exist?('os-autoinst')
  system('git clone https://github.com/os-autoinst/os-autoinst.git') || raise
end

Dir.chdir('os-autoinst') do
  system('git pull --rebase') || raise
  system('autoreconf -f -i') || raise
  system('./configure') || raise
  system('make') || raise

  ## builddeps
  warn('cpanm --installdeps --no-sudo  --notest .')
  unless system('cpanm --installdeps --no-sudo  --notest .')
    Dir.glob("#{Dir.home}/.cpanm/work/*/build.log").each do |log|
      5.times { puts }
      puts "----------------- #{log} -----------------"
      puts File.read(log)
    end
    raise 'capnm install failed'
  end
end
