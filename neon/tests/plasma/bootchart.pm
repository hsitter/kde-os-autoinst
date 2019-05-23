# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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

    $self->boot_to_dm;

    select_console 'log-console';
    {
        assert_script_run 'export DEBIAN_FRONTEND=noninteractive';
        # enable deb-src
        assert_script_sudo 'sh -c \'echo "deb-src http://archive.ubuntu.com/ubuntu/ bionic main universe" >> /etc/apt/sources.list\'';
        assert_script_sudo 'sh -c \'echo "deb-src http://archive.ubuntu.com/ubuntu/ bionic-updates main universe" >> /etc/apt/sources.list\'';
        assert_script_sudo 'sh -c \'echo "deb-src http://archive.ubuntu.com/ubuntu/ bionic-security main universe" >> /etc/apt/sources.list\'';

        assert_script_sudo 'apt-get update', 60;
        assert_script_sudo 'apt-get -y build-dep systemd-bootchart', 60 * 5;
        assert_script_sudo 'apt-get -y install git', 60 * 5;

        assert_script_run 'wget http://proli.net/meu/plasma-boot/bootchart.sh';
        assert_script_sudo 'bash -xe bootchart.sh';

        # Replace regular session so we don't have to fiddle with sddm in order
        # to log into the bootchart session.
        assert_script_sudo 'mv /usr/share/xsessions/plasma-bootchart.desktop /usr/share/xsessions/plasma.desktop';
        # And fix the name so the existing needle matches it.
        assert_script_sudo 'sed -i "s%Name=.*%Name=Plasma%g" /usr/share/xsessions/plasma.desktop';

        script_sudo 'systemctl restart sddm.service'
    }
    select_console 'x11';

    $self->boot;

    assert_screen 'folder-desktop';
    sleep(30); # Random wait in the hopes that the session fully started by the end.

    select_console 'log-console';
    my @svgs = split("\n", script_output('ls -1 /tmp/*.svg'));
    foreach my $svg (@svgs) {
        upload_logs $svg;
    }
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;
