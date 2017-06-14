#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
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

require "#{Dir.home}/tooling/lib/ci/containment"

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

DIST = ENV.fetch('DIST')
JOB_NAME = ENV.fetch('JOB_NAME')
PWD_BIND = ENV.fetch('PWD_BIND', '/workspace')

dev_kvm = {
  PathOnHost: '/dev/kvm',
  PathInContainer: '/dev/kvm',
  CgroupPermissions: 'mrw'
}

if ARGV.any? { |x| x.include?('bootstrap') } # Start a live data server
  require 'webrick'
  s = WEBrick::HTTPServer.new(DocumentRoot: '.', Port: 0,
                              BindAddress: '0.0.0.0')
  Thread.new do
    shutdown = proc do
      warn 'shutting down httpserver'
      s.shutdown
    end
    siglist = %w[TERM QUIT]
    siglist.concat(%w[HUP INT]) if STDIN.tty?
    siglist &= Signal.list.keys
    siglist.each do |sig|
      Signal.trap(sig, shutdown)
    end
    warn 'starting server'
    s.start
  end

  warn "Live data @ http://build.neon.kde.org:#{s.config.fetch(:Port)}.\n" \
    'Disappears on exit.'
end

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: ["#{Dir.pwd}:#{PWD_BIND}"],
                        privileged: false)
env = []
env << 'INSTALLATION=1' if ENV.include?('INSTALLATION')
env << "TESTS_TO_RUN=#{ENV['TESTS_TO_RUN']}" if ENV['TESTS_TO_RUN']
status_code = c.run(Cmd: ARGV, WorkingDir: PWD_BIND,
                    Env: env,
                    HostConfig: { Devices: [dev_kvm] })
exit status_code
