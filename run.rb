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
require 'json'

require_relative 'junit'

# not a typo 鑊!
FileUtils.rm_r('wok') if File.exist?('wok')
Dir.mkdir('wok')
Dir.chdir('wok')

cpus = `nproc`.strip.to_i
# Cloud scaled node, use all cores, else only half of them to not impair
# other functionality on the node.
cpus = (cpus / 2.0).ceil unless File.exist?('/tooling/is_scaling_node')

config = {
  BACKEND: 'qemu',
  CDMODEL: 'virtio-scsi-pci',
  DESKTOP: 'kde',
  DISTRI: 'debian',
  PRJDIR: '/workspace',
  CASEDIR: '/workspace/neon',
  ISO: '/workspace/neon.iso',
  PRODUCTDIR: '/workspace/neon',
  QEMUVGA: 'cirrus',
  TESTDEBUG: true,
  QEMUCPUS: cpus
}

# Neon builders don't do KVM, disable it if the module is not loaded.
config[:QEMU_NO_KVM] = true unless system('lsmod | grep -q kvm_intel')

File.write('vars.json', JSON.generate(config))
File.write('live_log', '')
system({ 'QEMU_AUDIO_DRV' => 'none' },
       '../os-autoinst/isotovideo', '-d') || raise

Dir.chdir('..')
JUnit.from_openqa('wok/testresults')
