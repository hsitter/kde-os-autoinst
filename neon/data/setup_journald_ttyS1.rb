#!/usr/bin/env ruby
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
#
# This program is free software) || raise you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation) || raise either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY) || raise without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# ttyS1 is set up by our kvm wrapper, it ordinarily isn't available
# Also see bin/kvm_arg_injector for additional information.
puts "#{$0} Letting systemd-journald log to ttyS1."
system 'sed -i "s%.*ForwardToConsole=.*%ForwardToConsole=yes%g" /etc/systemd/journald.conf' || raise
system 'sed -i "s%.*TTYPath=.*%TTYPath=/dev/ttyS1%g" /etc/systemd/journald.conf' || raise
system 'systemctl restart systemd-journald' || raise

# Ubuntu by default is hardened. To ease debugging we'll want full sysrq access.
# This is done in here since this is the only helpe rurn by both regular tests
# and live tests.
puts "#{$0} Enabling sysrq."
File.write('/proc/sys/kernel/sysrq', '1')
