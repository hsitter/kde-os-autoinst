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

    release_key('l');
    release_key('alt');
    release_key('ctrl');

    assert_screen('plasma-locked');
}

sub run {
    # NB: do not go into any consoles after this, they show up in the user
    #   switch dialog!
    # Before we start the lock screen test make sure we aren't logged in on
    # our terminal.
    # Otherwise the tty6 session would show up in the switch and make results
    # unreliable.
    select_console 'log-console';
    {
      script_run 'exit', 0;
      # Make sure logout actually happened. We have had cases where tty6
      # magically appeared in the switch dialog, supposedly because exit failed.
      # NOTE: Unfortunately we cannot assert anything here. On 18.04+ we'd
      # automatically switch to the remaining active VT (x11), so the state of
      # vt6 is left a mystery.
      # Whether the sleep actually helps with anything is unknown. But one can
      # hope.
      sleep 4;
      reset_consoles;
    }
    select_console 'x11';

    x11_start_program 'kcmshell5 screenlocker' ;
    assert_screen 'kcm-screenlocker';
    assert_and_click 'kcm-screenlocker-appearance';
    assert_screen 'kcm-screenlocker-appearance-type';
    if (match_has_tag('kcm-screenlocker-appearance-type-is-color')) {
        # TODO: drop once all images have been rotated (~mid Sept 2018)
        record_soft_failure 'Testing an old disk image without static lockscreen';
        assert_and_click 'kcm-screenlocker-appearance-type';
        assert_and_click 'kcm-screenlocker-appearance-type-color';
    }
    # Should the deafault ever become undesirable: #1d99f3 is the lovely color.
    assert_and_click 'kcm-ok';

    lock_screen;

    # simple unlock
    type_password $testapi::password;
    send_key 'ret';
    assert_screen 'folder-desktop';

    lock_screen;
    assert_screen('plasma-locked-idle');
    mouse_set(1, 1);
    mouse_hide;
    # NB: do not use esc. Esc is a toggle key. If it is not idle anymore esc
    #   will make it idle again!
    send_key 'ctrl'; # make double sure it's unidled

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
    assert_and_click 'plasma-launcher', undef, 60; # 60 seconds since we don't assert desktop
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
