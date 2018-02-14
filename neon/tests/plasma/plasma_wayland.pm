# Copyright (C) 2018 Bhavisha Dhruve <bhavishadhruve@gmail.com>
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

use base "basetest_neon";
use strict;
use testapi;

sub run {
    my ($self) = @_;

    $self->boot_to_dm(run_setup => 0);

    # Wayland testing needs to happen with qxl VGA. BUT qxl has artifact bugs
    # on 16.04, so we'll switch out the kernel for one that doesn't suffer from
    # this problem.
    # This strictly speaking makes the test less representitive, but is still
    # loads better than not having the test pass at all.
    # TODO: can be dropped for 18.04
    select_console 'log-console';
    {
        assert_script_run 'wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.15.3/linux-image-4.15.3-041503-generic_4.15.3-041503.201802120730_amd64.deb',  60 * 5;
        assert_script_sudo 'apt install -y `pwd`/linux-image-4.15.3-041503-generic_4.15.3-041503.201802120730_amd64.deb', 60 * 2;
        script_sudo 'reboot', 0;
    }
    reset_consoles;

    $self->boot_to_dm; # don't need the x11 session, we'll switch to wayland.

    select_console 'log-console';
    {
        assert_script_sudo 'apt update';
        assert_script_sudo 'apt install -y plasma-wayland-desktop';
    }
    select_console 'x11';

    assert_and_click 'sddm-choose-session';
    assert_and_click 'sddm-plasma-wayland';

    $self->login;

   assert_screen 'folder-desktop', 60;

}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;
