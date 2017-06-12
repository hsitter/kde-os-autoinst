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

#     # press enter to boot right away
#     send_key "ret";

    # wait for the desktop to appear
    assert_screen 'desktop', 180;

    # Installer
    assert_and_click "installer-icon";
    assert_screen "installer-welcome", 30;
    assert_and_click "installer-next";
    assert_screen "installer-prepare", 8;
    assert_and_click "installer-next";
    assert_screen "installer-disk", 8;
    assert_and_click "installer-install-now";
    assert_screen "installer-disk-confirm", 8;
    assert_and_click "installer-disk-confirm-continue";
    assert_screen "installer-welcome", 8;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;

# vim: set sw=4 et:
