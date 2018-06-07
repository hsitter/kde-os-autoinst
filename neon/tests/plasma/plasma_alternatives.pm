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
    assert_screen 'folder-desktop';
    
    # Starts the Alternative Menu
    assert_and_click 'plasma-launcher', 'right';
    
    # Selects the Application Menu
    assert_and_click 'kickoff-alternatives';
    assert_and_click 'kickoff-alternatives-popup';
    
    # Switches to Application Menu
    assert_and_click 'plasma-alternatives-switch';
    assert_screen 'folder-desktop';
    
    # Check if kicker opens instead of kickoff
    assert_and_click 'plasma-launcher';
    assert_screen 'plasma-kicker';
    send_key 'esc';
    
    # Roll back to kickoff
    assert_and_click 'plasma-launcher', 'right';
    assert_and_click 'kickoff-alternatives';
    assert_and_click 'kickoff-alternatives-launcher';
    assert_and_click 'plasma-alternatives-switch';
    assert_screen 'folder-desktop';
    assert_and_click 'plasma-launcher';
    assert_screen 'kickoff-popup';
    wait_still_screen;
    send_key 'esc';
    wait_still_screen;
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
 
