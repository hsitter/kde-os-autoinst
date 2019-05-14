# Copyright (C) 2018 Bhavisha Dhruve <bhavishadhruve@gmail.com>
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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

sub switch_to {
    my ($type) = @_;

    do {
        # Close open popup if there is any.
        send_key 'esc';
        send_key 'esc';
        send_key 'esc';

        # Starts the Alternative Menu
        assert_and_click 'plasma-launcher', button => 'right';

        # Selects the menu type.
        assert_and_click 'kickoff-alternatives';
        assert_screen "kickoff-alternatives-$type";

        # Repeat this entire dance if the popup has corrupted graphics.
        # This happens every so often and renders the popup incorrectly. If
        # we were to click at this point we'd be selecting an off-by-one item.
        # instead of the intended one.
        # Cause unknown.
    } while (match_has_tag 'kickoff-alternatives-corrupted');

    # Select type.
    assert_and_click "kickoff-alternatives-$type";
    # Apply the switch.
    assert_and_click 'plasma-alternatives-switch';
}

sub run {
    my ($self) = @_;
    assert_screen 'folder-desktop';

    # Switch to menu (kicker)
    switch_to 'menu';

    assert_screen 'folder-desktop';

    # Check if kicker opens instead of kickoff
    assert_and_click 'plasma-launcher';
    assert_screen 'plasma-kicker';
    send_key 'esc';

    # Starting a new session
    $self->logout;

    # Back in the session
    $self->login;
    assert_screen 'folder-desktop';

    # Roll back to launcher (kickoff)
    switch_to 'launcher';

    assert_screen 'folder-desktop';
    assert_and_click 'plasma-launcher';
    assert_screen 'kickoff-popup';
    sleep 2;
    send_key 'esc';
    assert_screen 'folder-desktop';
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;
