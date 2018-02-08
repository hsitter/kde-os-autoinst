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

sub run {
    my ($self) = @_;
    $self->boot;

    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('upgrade_bionic.rb'),  16;
        assert_script_sudo 'ruby upgrade_bionic.rb', 60 * 60;
    }
    select_console 'x11';

    # x11_start_program 'kubuntu-devel-release-upgrade';
    x11_start_program 'konsole';
    assert_screen 'konsole';
    type_string 'kubuntu-devel-release-upgrade';
    send_key 'ret';

    assert_screen 'kdesudo';
    type_password $testapi::password;
    send_key 'ret';

    assert_screen 'ubuntu-upgrade-fetcher-notes';
    assert_and_click 'ubuntu-upgrade-fetcher-notes';

    assert_screen 'ubuntu-upgrade';

    reset_consoles;
    $self->boot;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    select_console 'log-console';

    assert_script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    upload_logs '/tmp/journal.txt';

    upload_logs '/var/log/dpkg.log';
    upload_logs '/var/log/apt/term.log';
    upload_logs '/var/log/apt/history.log';

    # dist-upgrade simulation from upgrade_bionic.rb
    upload_logs '/tmp/simulation.txt';
    # real
    upload_logs '/tmp/upgrade.txt';
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;
