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
use testapi;

# Doesn't really do much beyond installing all packages. It's meant to be used
# before more useful tests that would need all packages installed.

sub run {
    my ($self) = @_;
    # Do not log in here. basetest can't tell if a boot has happened, so it
    # must finde the DM to know what it needs to do when a subsequent test calls
    # `boot` on it.
    $self->boot_to_dm;

    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('install_all.rb'),  16;
        assert_script_sudo 'ruby install_all.rb', 60 * 45;
    }
    select_console 'x11';

    # Make sure sddm isn't idle. Not sure if basetest knows to unidle
    # sddm when it encounters it in the beginning (versus the end)
    send_key 'ctrl';
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    select_console 'log-console';

    upload_logs '/var/log/dpkg.log';
    upload_logs '/var/log/apt/term.log';
    upload_logs '/var/log/apt/history.log';
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;
