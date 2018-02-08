# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

sub send_key_while_needlematch {
    my ($tag, $key, $counter, $timeout) = @_;

    $counter //= 20;
    $timeout //= 1;
    while (check_screen($tag, $timeout)) {
        send_key $key;
        if (!$counter--) {
            if (check_screen($tag, $timeout)) {
                die "Wanted to get rid of match for " . $tag . " but timed out";
            }
        }
    }
}

sub xkill_while_needlematch {
    my ($tag, $counter, $timeout) = @_;

    $counter //= 20;
    $timeout //= 1;
    while (check_screen($tag, $timeout)) {
        send_key 'alt-ctrl-esc';
        mouse_set(32, 32);
        # TODO: should assert_screen on the kill icon
        assert_and_click($tag);
        if (!$counter--) {
            if (check_screen($tag, $timeout)) {
                die "Wanted to get rid of match for " . $tag . " but timed out";
            }
        }
    }
}

sub run {
    my ($self) = @_;
    $self->boot;

    select_console 'log-console';
    assert_script_run 'wget ' . data_url('qt_compat_install.rb'),  16;
    assert_script_sudo 'ruby qt_compat_install.rb '.
                       'kdevelop skrooge kontact plasma-discover',
                       60 * 30;
    select_console 'x11';

    assert_screen 'folder-desktop', 30;
    # In case we have any lingering windows for whatever weird reason:
    send_key_while_needlematch('breeze-close', 'alt-f4', 20, 2);

    x11_start_program 'discover' ;
    assert_screen 'breeze-close';
    send_key_while_needlematch('breeze-close', 'alt-f4', 20, 2);

    x11_start_program 'kdevelop';
    assert_screen 'breeze-close';
    send_key_while_needlematch('breeze-close', 'alt-f4', 20, 2);

    x11_start_program('skrooge');
    assert_screen 'breeze-close';
    send_key_while_needlematch('breeze-close', 'alt-f4', 20, 2);

    x11_start_program('kontact');
    # apparently you can't close the kontact account wizard with alt-f4. wtf.
    # https://bugs.kde.org/show_bug.cgi?id=388815
    # instead we xkill it. We'll then continue closing as per usual.
    xkill_while_needlematch('breeze-close', 20, 2);
    assert_and_click 'breeze-close';
    send_key_while_needlematch('breeze-close', 'alt-f4', 20, 2);

    # If all went fine we should match our desktop again!
    assert_screen 'folder-desktop', 30;
}

1;
