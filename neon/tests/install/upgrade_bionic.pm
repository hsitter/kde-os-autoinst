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

sub kscreenlocker_disable {
    x11_start_program 'kcmshell5 screenlocker' ;
    assert_screen 'kcm-screenlocker';
    if (match_has_tag 'kcm-screenlocker-enabled') {
        assert_and_click 'kcm-screenlocker-disable';
    }
    assert_screen 'kcm-screenlocker-disabled';
    assert_and_click 'kcm-ok';
}

sub run {
    my ($self) = @_;
    $self->boot;

    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('upgrade_bionic.rb'),  16;
        assert_script_sudo 'ruby upgrade_bionic.rb', 60;
    }
    select_console 'x11';

    # Disable screen locker, this is gonna take a while.
    kscreenlocker_disable;

    # x11_start_program 'distro-release-notifier';
    x11_start_program 'konsole';
    assert_screen 'konsole';
    type_string 'distro-release-notifier';
    send_key 'ret';

    assert_and_click 'distro-release-notifier';
    assert_screen 'kdesudo';
    type_password $testapi::password;
    send_key 'ret';

    assert_screen 'ubuntu-upgrade-fetcher-notes';
    assert_and_click 'ubuntu-upgrade-fetcher-notes';

    assert_screen 'ubuntu-upgrade';
    # ... preparation happens ...
    assert_and_click 'ubuntu-upgrade-start', 'left', 60 * 5;
    # A config was changed by us to force the bionic upgrade to be enabled,
    # we should get a diff prompt.
    assert_and_click 'ubuntu-upgrade-diff', 'left', 60 * 10;
    assert_and_click 'ubuntu-upgrade-remove', 'left', 60 * 10;

    assert_screen 'ubuntu-upgrade-restart', 'left', 60 * 5;

    # upload logs in case something went wrong!
    select_console 'log-console';
    {
        assert_script_sudo 'tar -cJf /tmp/dist-upgrade.tar.xz /var/log/dist-upgrade/';
        upload_logs '/tmp/dist-upgrade.tar.xz';

        # NB: this hardcodes unstable, when we introduce other tests this needs
        #   fixing somehow (map types to repos in a hash?)
        validate_script_output "cat /etc/apt/sources.list.d/neon.list",
            sub { m{.*^(\s?)deb(\s?)http://archive.neon.kde.org/dev/unstable(\s?)bionic(\s?)main.*} };
    }
    select_console 'x11';

    assert_and_click 'ubuntu-upgrade-restart';

    # Switch to bionic mode now.
    # This among other things makes sure the right virtual terminals will be
    # used for x11 etc.
    set_var 'OPENQA_SERIES', 'bionic', reload_needles => 1;
    console('x11')->set_tty(1);
    reset_consoles;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    select_console 'log-console';

    upload_logs '/var/log/dpkg.log';
    upload_logs '/var/log/apt/term.log';
    upload_logs '/var/log/apt/history.log';

    # Try to get the dist upgrade log. It might not exist depending on when
    # the failure occured though.
    script_sudo 'tar -cJf /tmp/dist-upgrade.tar.xz /var/log/dist-upgrade/';
    upload_logs '/tmp/dist-upgrade.tar.xz', failok => 1;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;
