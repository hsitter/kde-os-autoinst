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

ISOTOVIDEO = if File.exist?('/opt/os-autoinst/isotovideo') &&
                !ENV['OPENQA_OS_AUTOINST_IN_TREE']
               '/opt/os-autoinst/isotovideo'
             else
               File.expand_path('os-autoinst/isotovideo')
             end

# FIXME: we really want 20G to not accidently risk out of disking the server
#   if a test has a data leak. OTOH we need larger setups for some tests.
#   might be worth investing into a solution that can dynamically upscale a
#   20G base image (would need larger overlay + resizing the partition table)
DISK_SIZE_GB = '30'.freeze

ENV['PERL5LIB'] = PERL5LIB

puts 'kvm-ok?'
system 'kvm-ok'
system 'ls -lah /dev/kvm'

# os-autoinst internally hosts a mojo server to shove assets between host and
# guest, this controls the debuggyness there.
# MOJO_LOG_LEVEL=debug

# not a typo 鑊!
# FIXME: hack while we run everything in the same job we need to only clean the
#   wok on the initial installation test. otherwise we lose data.
if ENV['INSTALLATION']
  FileUtils.rm_r('wok') if File.exist?('wok')
end
Dir.mkdir('wok') unless File.exist?('wok')
Dir.chdir('wok')

FileUtils.rm_rf('../metadata', verbose: true)
FileUtils.mkdir('../metadata', verbose: true)

# Cloud scaled node, use all cores, else only half of them to not impair
# other functionality on the node.
cpus = Etc.nprocessors
cpus = (cpus / 2.0).ceil unless File.exist?('/tooling/is_scaling_node')

defaultvga = 'qxl'

config = {
  BACKEND: 'qemu',
  CDMODEL: 'virtio-scsi-pci',
  DESKTOP: 'kde',
  DISTRI: 'debian',
  PRJDIR: '/workspace',
  CASEDIR: '/workspace/neon',
  PRODUCTDIR: '/workspace/neon',
  # cirrus: old std, doesn't do wayland
  # qxl: used for spice as well. as special guest driver. works with wayland.
  #   doesn't clear/redraw screen on VT switch properly,
  #   causing rendering artifacts prevent screen matches
  # std: new standard. has 800x600 resolution for some reason
  # virtio/virgil: broke uefi display init somehow. not actually built with
  #   3d accel on debian/ubuntu. needs passing of options to actually enable
  #   accel -display sdl,gl=on`
  #   https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=813658
  QEMUVGA: ENV.fetch('QEMUVGA', defaultvga),
  TESTDEBUG: false,
  MAKETESTSNAPSHOTS: false,
  QEMUCPUS: cpus,
  QEMURAM: 2048,
  HDDSIZEGB_1: DISK_SIZE_GB, # G is appended by os-autoinst
  UEFI_BIOS: '/usr/share/OVMF/OVMF_CODE.fd',
  UEFI: 1,
  QEMU_COMPRESS_QCOW2: true,
  TYPE: ENV.fetch('TYPE')
}

ENV.each { |k, v| config[k.to_sym] = v if k.start_with?('OPENQA_') }

# The 16.04 ovmf doesn't work with virtio/virgil3d VGA and fails to init the
# display. Use a binary copy of the bionic build
#   ovmf_0~20171205.a9212288-1_all.deb
# The secondary "OVMF-pure-efi" is from kraxel.org
#   edk2.git-ovmf-x64-0-20180807.244.gde005223b7.noarch.rpm
# There's also fancy builds at https://www.kraxel.org/repos/jenkins/edk2/
# which contain more pertinent stuff.
bionic_ovmf = File.expand_path("#{__dir__}/../OVMF/OVMF_CODE.fd")
config[:UEFI_BIOS] = bionic_ovmf if File.exist?(bionic_ovmf)

# Switch to bios mode when requested.
config.delete(:UEFI) if ENV['OPENQA_BIOS']

config[:TESTS_TO_RUN] = ENV['TESTS_TO_RUN']
config[:PLASMA_DESKTOP] = ENV['PLASMA_DESKTOP']
if ENV['INSTALLATION']
  config[:INSTALLATION] = ENV['INSTALLATION']
  config[:INSTALLATION_OEM] = ENV['INSTALLATION_OEM']
  config[:ISO] = '/workspace/neon.iso'
  if ENV['OPENQA_PARTITIONING']
    # explicitly boot from ISO. for ubiquity we need to reboot, ordinarily
    # qemu would then boot from the HDD if it has an ESP, we never want to
    # boot from HDD in partitioning tests though.
    config[:BOOTFROM] = 'cdrom'
  end

  if ENV['OPENQA_SECUREBOOT']
    # https://fedoraproject.org/wiki/Using_UEFI_with_QEMU#Testing_Secureboot_in_a_VM
    # https://rpmfind.net/linux/rpm2html/search.php?query=edk2-ovmf
    secureboot = File.expand_path("#{__dir__}/../OVMF/SecureBoot.iso")
    config[:ISO_1] = secureboot
    config[:SECUREBOOT] = true
  end
else
  config[:BOOT_HDD_IMAGE] = true
  config[:KEEPHDDS] = true

  # Re-use existing raid/, comes from install test.
  os_auto_inst_dir = File.join('/srv/os-autoinst/',
                               ENV.fetch('OPENQA_SERIES'),
                               ENV.fetch('TYPE'))
  os_auto_inst_raid = "#{os_auto_inst_dir}/wok/raid"
  if File.exist?(os_auto_inst_raid)
    # Do not explode on recylced build dirs which might still have the origin
    # symlink linger.
    FileUtils.rm_f('../raid')
    FileUtils.ln_s(os_auto_inst_raid, '../raid')

    # Copy base image metadata
    if File.exist?("#{os_auto_inst_dir}/metadata/")
      FileUtils.cp_r("#{os_auto_inst_dir}/metadata/.",
                     '../metadata/',
                     verbose: true)
    end
  end

  # This is separate from the os-autinst recycling as you can manually simulate
  # it by simplying moving a suitable raid in place. This is for localhost
  # usage. On CI systems we alway should hit the os-autoinst path and symlink
  # the raid.
  existing_raid = File.realpath('../raid')
  if File.exist?(existing_raid)
    warn "Overlaying existing #{existing_raid}"

    FileUtils.rm_r('raid') if File.exist?('raid')
    FileUtils.mkpath('raid')
    unless system("qemu-img create -f qcow2 -o backing_file=#{existing_raid}/1 raid/1 #{DISK_SIZE_GB}G")
      raise "Failed to create overlay for #{existing_raid}"
    end
    system('qemu-img info raid/1')
  end
  config[:QEMU_DISABLE_SNAPSHOTS] = true
  config[:MAKETESTSNAPSHOTS] = false
end

# Set our wrapper as qemu. It transparently injects hugepages options
# to the call when possible, to increase performance. And other stuff.
ENV['QEMU'] = File.join(__dir__, 'kvm_arg_injector')

if ENV['PLASMA_MOBILE']
  config[:ISO] = '/workspace/neon-pm.iso'
  config[:BOOT_HDD_IMAGE] = false
  config[:KEEPHDDS] = false
end

warn "Going to use #{cpus} Cores"
warn "Going to use KVM: #{!config.include?(:QEMU_NO_KVM)}"
warn "Running from #{ISOTOVIDEO}"

File.write('vars.json', JSON.generate(config))
File.write('live_log', '')
system({ 'QEMU_AUDIO_DRV' => 'none' }, ISOTOVIDEO, '-d') || raise

Dir.chdir('..')

Dir.glob('wok/ulogs/metadata-*') do |file|
  target = File.basename(file)
  target = target.split('-', 2)[-1]
  FileUtils.mv(file, File.join('metadata', target), verbose: true)
end

# Generate a slideshow and ignore return value. If this fails chances are junit
# will too, if junit doesn't fail we'd not care that slideshow failed. This is
# more of a bonus feature.
system("#{__dir__}/slideshow.rb", 'wok/slide.html')

JUnit.from_openqa('wok/testresults')
