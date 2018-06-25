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

# Unfortunately kteatime has fairly bad first use UX and doesn't show anything
# by default. We'll need special code to get to anything we can assert.
# https://bugs.kde.org/show_bug.cgi?id=394855
sub run {
    my ($self) = @_;

    $self->boot;
    $self->enable_snapd_and_install_snap;

    x11_start_program '/snap/bin/kteatime';
    send_key 'ret';

    # Getting to the UI is nigh impossible at this time because our default
    # image still has a non static wallpaper which makes asserting the tray a
    # pain in the ass as the tray popup is translucent and the wallpaper is
    # massively bleeding through.
    # Instead simply assert the app didn't terminate again.
    # TODO: this can be changed to assert the tray icon once the base image
    #   has a static wallpaper.
    select_console 'log-console';
    {
        assert_script_run 'pidof kteatime'
    }
    select_console 'x11';
}

1;
