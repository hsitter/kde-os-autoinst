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

use base "basetest_neon";
use strict;
use testapi;

sub lock_screen {
    hold_key('ctrl');
    hold_key('alt');
    hold_key('l');

    assert_screen('plasma-locked');

    release_key('l');
    release_key('alt');
    release_key('ctrl');
}

sub run {
    # Before we start the lock screen test make sure we aren't logged in on
    # our terminal.
    # Otherwise the tty6 session would show up in the switch and make results
    # unreliable.
    select_console 'log-console';
    script_run 'exit', 0;
    reset_consoles;
    select_console 'x11';

    lock_screen;

    # simple unlock
    type_password $testapi::password;
    send_key 'ret';
    assert_screen 'folder-desktop', 60;

    lock_screen;
    assert_screen('plasma-locked-idle');
    mouse_set(1, 1);
    mouse_hide;

    # virtual keyboard
    assert_and_click 'plasma-locked-keyboard-icon';
    assert_screen 'plasma-locked-keyboard';
    assert_and_click 'plasma-locked-keyboard-q';
    assert_and_click 'plasma-locked-keyboard-q';
    # qq in password field
    assert_screen 'plasma-locked-keyboard-qq', no_wait => 1;
    send_key 'backspace';
    send_key 'backspace';
    assert_and_click 'plasma-locked-keyboard-icon-active';

    assert_screen 'plasma-locked';

    # switch user
    assert_and_click 'plasma-locked-switch-icon';
    assert_and_click 'plasma-locked-switch';
    assert_screen 'sddm';
    type_password $testapi::password;
    send_key 'ret';
    # ugh, sddm has no way to get us back, start a new session?
    wait_still_screen;
    assert_and_click 'kickoff', undef, 60; # 60 seconds since we don't assert desktop
    assert_and_click 'kickoff-leave';
    assert_and_click 'kickoff-leave-logout';
    assert_and_click 'ksmserver-logout';
    wait_still_screen;

    # we are back in our regular session, unlock and be happy
    # done

    unless (get_var("QEMUVGA") eq 'qxl') {
        # This is confirmed to not be a problem on qxl. Should we switch to
        # other VGAs in the future we'll know if they are exhibiting the
        # problem too as we only skip qxl.
        record_soft_failure 'kscreenlocker comes back with vkbd bug 387270';
        assert_and_click 'plasma-locked-keyboard-icon-active';
    }

    type_password $testapi::password;
    send_key 'ret';
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
