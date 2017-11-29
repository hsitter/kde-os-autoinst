# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package basetest_neon;
use base 'basetest';

use testapi;
use strict;

sub login {
    my ($self) = @_;
    # Short wait, we should be close to sddm if we this gets called.
    assert_screen 'sddm', 120;
    $self->maybe_login;
}

sub maybe_login {
    # Short wait, we should be close to sddm if we this gets called.
    if (check_screen 'sddm', 16) {
        type_password $testapi::password;
        send_key 'ret';
        wait_still_screen;
    }
}

# Waits for system to boot to desktop.
sub boot {
    my ($self, $args) = @_;

    assert_screen 'grub';
    send_key 'ret'; # start first entry

    # Eventually we should end up in sddm
    assert_screen 'sddm', 120;

    select_console 'log-console';
    # Should probably be put in a script that globs all snapd*timer
    script_sudo 'systemctl disable --now snapd.refresh.timer';
    script_sudo 'systemctl disable --now snapd.refresh.service';
    script_sudo 'systemctl disable --now snapd.snap-repair.timer';
    script_sudo 'systemctl disable --now snapd.service';

    script_sudo "touch /etc/apt/apt.conf.d/proxy; sudo chown $testapi::username /etc/apt/apt.conf.d/proxy";
    script_run 'echo "Acquire::http { Proxy \"http://10.0.2.2:3142\"; };" > /etc/apt/apt.conf.d/proxy';
    script_sudo 'touch /etc/apt/apt.conf.d/proxy; sudo chown root /etc/apt/apt.conf.d/proxy';

    select_console 'x11';

    type_password $testapi::password;
    send_key 'ret';

    wait_still_screen;
}

sub enable_snapd {
    my ($self, $args) = @_;
    select_console 'log-console';
    assert_script_sudo 'systemctl enable --now snapd.service';
    assert_script_sudo 'snap refresh', 30 * 60;
    select_console 'x11';
}

1;
