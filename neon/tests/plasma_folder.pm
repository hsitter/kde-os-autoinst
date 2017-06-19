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
    assert_screen "grub", 30;
    send_key 'ret'; # start first entry

    # Eventually we should end up in sddm
    assert_screen "sddm", 120;

    type_password $testapi::password;
    send_key 'ret';

    # wait for the desktop to appear
    # Technically we'd want to make sure the desktop appears in under 30s but
    # since we can't make sure that is in fact the baseline we can't really do
    # that :/
    # >30s would be indicative of a dbus timeout.
    assert_screen 'folder-desktop', 120;
    wait_idle; # Make sure system has settled down a bit.

    assert_and_click "home-icon";
    wait_idle;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;
