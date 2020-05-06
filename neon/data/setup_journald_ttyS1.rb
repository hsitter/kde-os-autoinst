#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2018-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

# On newer openqa's there'll be a builtin virtioconsole we can utilize.
# Indicator will be a virtio port.
dev = if Dir.glob('/dev/virtio-ports/org.openqa.console.*').empty?
        '/dev/ttyS1'
      else
        '/dev/hvc0'
      end

# ttyS1 is set up by our kvm wrapper, it ordinarily isn't available
# Also see bin/kvm_arg_injector for additional information.
puts "#{$0} Letting systemd-journald log to #{dev}."
system 'sed -i "s%.*ForwardToConsole=.*%ForwardToConsole=yes%g" /etc/systemd/journald.conf' || raise
system "sed -i 's%.*TTYPath=.*%TTYPath=#{dev}%g' /etc/systemd/journald.conf" || raise
system 'sed -i "s%.*MaxLevelConsole=.*%MaxLevelConsole=debug%g" /etc/systemd/journald.conf' || raise
system 'systemctl restart systemd-journald' || raise

# Ubuntu by default is hardened. To ease debugging we'll want full sysrq access.
# This is done in here since this is the only helpe rurn by both regular tests
# and live tests.
puts "#{$0} Enabling sysrq."
system 'sysctl kernel.sysrq=1' || raise;

# Turn on more systemd and kernel debuggyness to get more data should
# reboot fail to excute properly.
puts "#{$0} Enabling systemd and kernel debugging."
system '/bin/kill -SIGRTMIN+20 1' || raise; # systemd.show_status=1
system '/bin/kill -SIGRTMIN+22 1' || raise; # systemd.log_level=debug
system 'sysctl kernel.printk_devkmsg=on' || raise; # unlimited logging from userspace
system 'sysctl kernel.printk="7 7 7 7"' || raise; # kernel debug
