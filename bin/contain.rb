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
devices = []
devices << dev_kvm if File.exist?(dev_kvm[:PathOnHost])

binds = ["#{Dir.pwd}:#{PWD_BIND}"]
os_auto_inst_dir = '/srv/os-autoinst'
if File.exist?(os_auto_inst_dir)
  # Read-only bind our base disks if they exist.
  # rubocop:disable Style/FormatStringToken
  binds << format('%s:%s:ro', os_auto_inst_dir, os_auto_inst_dir)
  # rubocop:enable Style/FormatStringToken
end
warn "binding #{binds}"

c = CI::Containment.new(JOB_NAME.gsub('%2F', '/').tr('/', '-'),
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds,
                        privileged: false)

# Whitelist
ENV_VARS = %w[
  BUILD_URL
  INSTALLATION
  INSTALLATION_OEM
  NODE_NAME
  PLASMA_DESKTOP
  TESTS_TO_RUN
].freeze
env = {}
ENV_VARS.each { |x| env[x] = ENV[x] }
# Also all OPENQA_ vars are forwarded
ENV.each { |k, v| env[k] = v if k.start_with?('OPENQA_') }
env = env.map { |k, v| [k, v].join('=') if v }.compact

status_code = c.run(Cmd: ARGV, WorkingDir: PWD_BIND,
                    Env: env,
                    HostConfig: { Devices: devices })
exit status_code
