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

require 'etc'
require 'fileutils'
require 'json'

require_relative '../lib/junit'
require_relative '../lib/paths'

ISOTOVIDEO = if File.exist?('/opt/os-autoinst/isotovideo')
               '/opt/os-autoinst/isotovideo'
             else
               File.expand_path('os-autoinst/isotovideo')
             end

ENV['PERL5LIB'] = PERL5LIB

# os-autoinst internally hosts a mojo server to shove assets between host and
# guest, this controls the debuggyness there.
# MOJO_LOG_LEVEL=debug

# not a typo 鑊!
# FIXME: hack while we run everything in the same job we need to only clean the
#   wok on the initial installation test. otherwise we lose data.
if ENV['INSTALLATION']
  FileUtils.rm_r('wok') if File.exist?('wok')
  Dir.mkdir('wok')
end
Dir.chdir('wok')

# Cloud scaled node, use all cores, else only half of them to not impair
# other functionality on the node.
cpus = Etc.nprocessors
cpus = (cpus / 2.0).ceil unless File.exist?('/tooling/is_scaling_node')

config = {
  BACKEND: 'qemu',
  CDMODEL: 'virtio-scsi-pci',
  DESKTOP: 'kde',
  DISTRI: 'debian',
  PRJDIR: '/workspace',
  CASEDIR: '/workspace/neon',
  PRODUCTDIR: '/workspace/neon',
  QEMUVGA: 'cirrus',
  TESTDEBUG: false,
  MAKETESTSNAPSHOTS: false,
  QEMUCPUS: cpus,
  QEMURAM: 2048,
  UEFI_BIOS: '/usr/share/OVMF/OVMF_CODE.fd',
  UEFI: 1,
  # The video is fairly useless gimicky stuff. Also theora... if I wanted a
  # pixelated slideshow I'd use a more efficient pixelation algorithm.
  NOVIDEO: true,
  QEMU_COMPRESS_QCOW2: true
}

# Switch to bios mode when requested.
config.delete(:UEFI) if ENV['BIOS']

config[:TESTS_TO_RUN] = ENV['TESTS_TO_RUN'].split(':') if ENV['TESTS_TO_RUN']
if ENV['INSTALLATION']
  config[:INSTALLATION] = ENV['INSTALLATION']
  config[:ISO] = '/workspace/neon.iso'
else
  config[:BOOT_HDD_IMAGE] = true
  config[:KEEPHDDS] = true
  # Re-use existing raid/, comes from install test.
  if File.exist?('../raid')
    warn 'Importing existing ../raid'
    FileUtils.rm_r('raid')
    FileUtils.cp_r('../raid', '.')
  end
end

# Neon builders don't do KVM, disable it if the module is not loaded.
config[:QEMU_NO_KVM] = true unless system('lsmod | grep -q kvm_intel')

warn "Going to use #{cpus} Cores"
warn "Going to use KVM: #{!config.include?(:QEMU_NO_KVM)}"
warn "Running from #{ISOTOVIDEO}"

File.write('vars.json', JSON.generate(config))
File.write('live_log', '')
system({ 'QEMU_AUDIO_DRV' => 'none' }, ISOTOVIDEO, '-d') || raise

Dir.chdir('..')
JUnit.from_openqa('wok/testresults')
