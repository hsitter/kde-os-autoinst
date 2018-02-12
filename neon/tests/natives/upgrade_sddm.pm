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
    {
        assert_script_sudo 'apt update', 60 * 5;
        assert_script_sudo 'apt dist-upgrade -y', 60 * 15;
        assert_script_run 'wget https://origin.archive.neon.kde.org/dev/unstable/pool/main/n/neon-settings/neon-settings_0.0+p16.04+git20180212.0137_all.deb', 60 * 15;
        assert_script_sudo 'apt -y install `pwd`/neon-settings_0.0+p16.04+git20180212.0137_all.deb', 60 * 15;
        script_sudo 'reboot', 0;
        reset_consoles;
    }

    $self->boot;

    # If all went fine we should match our desktop again!
    assert_screen 'folder-desktop', 30;
}

1;
