# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

use base "basetest";
use strict;
use testapi;

sub run {
    # wait for bootloader to appear
    assert_screen 'bootloader', 30;

    # wait for the desktop to appear
    assert_screen 'desktop', 180;

    wait_idle; # Make sure system has settled down a bit.

    # Installer
    assert_and_click "installer-icon";
    assert_screen "installer-welcome", 30;
    assert_and_click "installer-next";
    assert_screen "installer-prepare", 16;
    assert_and_click "installer-next";
    assert_screen "installer-disk", 16;
    assert_and_click "installer-install-now";
    assert_screen "installer-disk-confirm", 16;
    assert_and_click "installer-disk-confirm-continue";

    # Timezone has 75% fuzzyness as timezone is geoip'd so its fairly divergent.
    # Also, starting here only the top section of the window gets matched as
    # the bottom part with the buttons now has a progressbar and status
    # text which is non-deterministic.
    # NB: we give way more leeway on the new needle appearing as disk IO can
    #   cause quite a bit of slowdown and ubiquity's transition policy is
    #   fairly weird when moving away from the disk page.
    assert_screen "installer-timezone", 60;
    assert_and_click "installer-next";
    assert_screen "installer-keyboard", 16;
    assert_and_click "installer-next";

    assert_screen "installer-user", 16;
    type_string "user";
    # user in user field, name field (needle doesn't include hostname in match)
    assert_screen "installer-user-user", 16;
    send_key "tab", 1; # username field
    send_key "tab", 1; # 1st password field
    type_string "password";
    send_key "tab", 1; # 2nd password field
    type_string "password";
    # all fields filled (not matching hostname field)
    assert_screen "installer-user-complete", 16;
    assert_and_click "installer-next";

    assert_screen "installer-show", 16;

    # Let install finish and restart
    assert_screen "installer-restart", 640;
    assert_and_click "installer-restart-now";

    assert_screen "live-remove-medium", 60;
    send_key "ret";

    reset_consoles;

    # Eventually we should end up in sddm
    assert_screen "sddm", 180;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    select_console 'x11';
    ensure_installed 'curl';

    select_console 'log-console';

    # Uploads end up in wok/ulogs/
    assert_script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    upload_logs '/tmp/journal.txt';
    assert_script_sudo 'tar cfJ /tmp/installer.tar.xz /var/log/installer';
    upload_logs '/tmp/installer.tar.xz';
}

1;
