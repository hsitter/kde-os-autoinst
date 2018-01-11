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

sub run {
    my ($self) = @_;
    $self->boot;

    select_console 'log-console';
    assert_script_run 'wget ' . data_url('qt_compat_install.rb'),  16;
    assert_script_sudo 'ruby qt_compat_install.rb '.
                       'kdevelop skrooge kontact',
                       60 * 30;
    select_console 'x11';

    assert_screen 'folder-desktop', 30;

    assert_screen_change { x11_start_program('kdevelop'); };
    assert_screen_change { send_key 'alt-f4'; }

    assert_screen 'folder-desktop', 30;

    assert_screen_change { x11_start_program('skrooge'); };
    # multiple windows...
    assert_screen_change { send_key 'alt-f4'; send_key 'alt-f4'; }

    assert_screen 'folder-desktop', 30;

    assert_screen_change { x11_start_program('kontact'); };
    # multiple windows...
    assert_screen_change { send_key 'alt-f4'; send_key 'alt-f4'; }

    assert_screen 'folder-desktop', 30;
}

1;
