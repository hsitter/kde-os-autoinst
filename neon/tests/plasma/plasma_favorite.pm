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

sub run {
    my ($self) = @_;
    assert_screen 'folder-desktop';

    # Starts the Application Launcher
    assert_and_click 'plasma-launcher';
    wait_still_screen;

    # Switches to the Application Tab
    assert_screen 'kickoff-favorite';
    assert_and_click 'kickoff-application';
    assert_and_click 'kickoff-office';

    # Adds Okular in the favorites tab
    assert_and_click 'kickoff-okular', button => 'right';
    assert_and_click 'kickoff-add-to-favorite';
    assert_screen 'kickoff-favorite-okular', 60;
    send_key 'esc';
    wait_still_screen;
    assert_and_click 'plasma-launcher';
    send_key 'esc';

    # Logging out from the session
    $self->logout;

    # Back in the session
    $self->login;
    assert_screen 'folder-desktop', 60;

    # Removes Okular from the favorites tab
    assert_and_click 'plasma-launcher';
    wait_still_screen;
    # Move the mouse far far away in an attempt to not hit
    # https://bugs.kde.org/show_bug.cgi?id=407517
    # which may also be a timing issue for us here as technically we shouldn't
    # be able to have the mouse already above the okular entry.
    mouse_set(0, 0);
    assert_and_click 'kickoff-favorite-okular', button => 'right';
    assert_and_click 'kickoff-remove-from-favorite';
    assert_screen ['kickoff-favorite-okular', 'kickoff-favorite'], 60;
    if (match_has_tag('kickoff-favorite-okular')) {
        die 'Okular should not be visible on the favorite tab'
    }

    # Close the kickoff otherwise next test will fail
    assert_and_click 'kickoff-dismiss';
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;
