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
    $self->boot_to_dm;

    # Setup a second user with an encrypted home. In ubiquity we never really
    # disabled home encryption as we didn't wanna support it but then it was
    # working fine and we had no reason to take away something that works.
    # Now we pay the price for that niceness.
    # As a basic requirement we'll want encrypted homes to be still encrypted
    # and accessible after the upgrade. Since we do not install encrypted
    # images though we'll have to manually setup an encrypted home first.
    # This isn't perfectly representive of how a ubiquity encrypted home
    # may look like, but it should be close enough.
    my $encrypt_user = 'encrypty';
    my $encrypt_password = 'password';
    select_console 'log-console';
    {
        # https://help.ubuntu.com/community/EncryptedHome
        assert_script_sudo 'apt update', 60;
        assert_script_sudo 'apt install -y ecryptfs-utils', 60 * 5;

        script_sudo "adduser --gecos '' --encrypt-home --force $encrypt_user", 0;
        assert_screen 'adduser-password1';
        type_string $encrypt_password;
        send_key 'ret';
        assert_screen 'adduser-password2';
        type_string $encrypt_password;
        send_key 'ret';
        assert_screen 'adduser-done';

        script_run 'logout', 0;

        assert_screen 'tty6-selected';
        type_string $encrypt_user;
        send_key 'ret';
        assert_screen 'tty-password';
        type_password $encrypt_password;
        send_key 'ret';

        # This is a bit stupid but we don't actually have a better way to
        # check except for looking at a completely new needle. Go with this
        # for now.
        sleep 4;

        validate_script_output 'ls', sub { m/^$/ };
        assert_script_run 'touch marker';
        validate_script_output 'ls', sub { m/^marker$/ };

        script_run 'logout', 0;
        reset_consoles;

        # Relogin by simply switching to the console again.
        select_console 'log-console';
        # Cache sudo password & make sure the home is unmounted!
        # https://wiki.ubuntu.com/EncryptedHomeFolder
        #   Sometimes pam fails to unmount your folder (esp if use
        #   graphical login), leaving it open even though your logged out.
        script_sudo "umount /home/$encrypt_user";
        # ...and make sure the home is encrypted!
        validate_script_output "sudo ls /home/$encrypt_user",
                               sub { m/Access-Your-Private-Data\.desktop.*/ };
    }
    select_console 'x11';

    select_console 'log-console';
    {
        # Install a suitable logging file so we can easily debug things in case
        # of failure.
        assert_script_run 'mkdir -pfv .config/QtProject/';
        assert_script_run 'wget -O .config/QtProject/qtlogging.ini ' . data_url('upgrade_bionic_qtlogging.ini');
    }
    select_console 'x11';

    $self->login;
    assert_screen 'folder-desktop', 30;

    # Disable screen locker, this is gonna take a while.
    kscreenlocker_disable;

    # x11_start_program 'distro-release-notifier';
    x11_start_program 'konsole';
    assert_screen 'konsole';
    # Assert that the notifier was auto-started.
    assert_script_run 'pidof distro-release-notifier';
    # And trigger a devel upgrade.
    type_string 'qdbus org.kde.DistroReleaseNotifier / org.kde.DistroReleaseNotifier.UseDevel true';
    send_key 'ret';

    assert_and_click 'distro-release-notifier';
    assert_and_click 'distro-release-notifier-2';
    assert_screen 'policykit';
    type_password $testapi::password;
    send_key 'ret';

    assert_screen 'ubuntu-upgrade-fetcher-notes';
    assert_and_click 'ubuntu-upgrade-fetcher-notes';

    assert_screen 'ubuntu-upgrade';
    # ... preparation happens ...
    assert_and_click 'ubuntu-upgrade-start', 'left', 60 * 5;
    # A config was changed by us to force the bionic upgrade to be enabled,
    # we should get a diff prompt.
    assert_and_click 'ubuntu-upgrade-diff-2', 'left', 60 * 10;
    # (This has a super long time out because upgrading an all-packages
    #  install takes forever)
    # TODO: consider finding a better way to detect problems than such a long
    #   time out. maybe assert [remove, standardwindow], if the window gets
    #   covered by an error or unexpected dialog we'd then abort immediately.
    assert_screen [qw(ubuntu-upgrade-error ubuntu-upgrade-remove)], 60 * 30;
    if (match_has_tag('ubuntu-upgrade-error')) {
        die 'We got error while upgrading.';
    }
    assert_and_click 'ubuntu-upgrade-remove', 'left';

    assert_screen 'ubuntu-upgrade-restart', 60 * 5;

    # upload logs in case something went wrong!
    select_console 'log-console';
    {
        assert_script_sudo 'tar -cJf /tmp/dist-upgrade.tar.xz /var/log/dist-upgrade/';
        upload_logs '/tmp/dist-upgrade.tar.xz';

        my %type_to_path = (
            'devedition-gitunstable' => 'dev/unstable',
            'devedition-gistable' => 'dev/stable',
            'useredition' => 'user',
            'userltsedition' => 'user/lts'
        );
        my $path = $type_to_path{$ENV{TYPE}};

        # NB: this hardcodes unstable, when we introduce other tests this needs
        #   fixing somehow (map types to repos in a hash?)
        validate_script_output "cat /etc/apt/sources.list.d/neon.list",
            sub { m{.*^(\s?)deb(\s?)http://archive.neon.kde.org/$path(\s?)bionic(\s?)main.*} };
    }
    select_console 'x11';

    assert_and_click 'ubuntu-upgrade-restart';

    # Switch to bionic mode now.
    # This among other things makes sure the right virtual terminals will be
    # used for x11 etc.
    set_var 'OPENQA_SERIES', 'bionic', reload_needles => 1;
    console('x11')->set_tty(1);
    reset_consoles;

    $self->boot_to_dm;

    # Before handing over to subsequent tests we'll assert encrypted homes
    # are still working.
    select_console 'log-console';
    {
        # We don't have access...
        validate_script_output "sudo ls /home/$encrypt_user",
                               sub { m/Access-Your-Private-Data\.desktop.*/ };
        # Switch to encrypted user and make sure it still has access to
        # its data after the upgrade though...
        script_run 'logout', 0;

        assert_screen 'tty6-selected';
        type_string $encrypt_user;
        send_key 'ret';
        assert_screen 'tty-password';
        type_password $encrypt_password;
        send_key 'ret';

        # This is a bit stupid but we don't actually have a better way to
        # check except for looking at a completely new needle. Go with this
        # for now.
        sleep 4;

        assert_script_run 'ls';
        validate_script_output 'ls', sub { m/^marker$/ };

        # And pop back to regular user.
        script_run 'logout', 0;
        reset_consoles;
    }
    select_console 'x11';

    # Make sure the evdev driver is installed. We prefer evdev at this time
    # instead of libinput since our KCMs aren't particularly awesome for
    # libinput.
    select_console 'log-console';
    {
        assert_script_run 'dpkg -s xserver-xorg-input-evdev';
        validate_script_output 'grep -e "Using input driver" /var/log/Xorg.0.log',
                               sub { m/.+evdev.+/ };
    }
    select_console 'x11';
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
