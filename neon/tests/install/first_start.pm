# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

# Core test to run for all install cases. Asserts common stuff.
sub run {
    my ($self) = @_;

    $self->boot_to_dm(run_setup => 0);

    # Let the system settle down a bit. There may be first start setup going on
    # slowing down IO responsiveness letting the following tty switch go
    # wrong. Best save than sorry.
    # (kinda hackish, ideally we shouldn't fail to accept vt switches :S)
    sleep 8;

    select_console 'log-console';

    assert_script_run 'wget ' . data_url('setup_journald_ttyS1.rb'),  16;
    assert_script_sudo 'ruby setup_journald_ttyS1.rb', 60 * 5;

    # General purpose hook.
    assert_script_run 'wget ' . data_url('early_first_start.rb'),  16;
    assert_script_sudo 'ruby early_first_start.rb', 60 * 5;

    # Assert that we have no preinstalled pool lingering around on the installed
    # rootfs. preinstalled-pool comes from our livecd-rootfs-neon fork and
    # contains bootloaders for offline install. This should be removed before
    # installation is finalized
    if (script_run('grep -r preinstalled-pool /etc/apt/') == 0) {
        die '/var/lib/preinstalled-pool is in /etc/apt/* after install';
    }
    if (script_run('[ -e /var/lib/preinstalled-pool ]') == 0) {
        die '/var/lib/preinstalled-pool exist after install';
    }

    # Make sure this system is bootable throughout all use cases by ensuring
    # our loader is used as fallback loader in EFI\boot\bootx64.efi
    assert_script_run 'wget ' . data_url('uefi_boot.rb'),  16;
    assert_script_sudo 'ruby uefi_boot.rb', 16;

    assert_script_run 'wget ' . data_url('enable_qdebug.rb'),  16;
    assert_script_run 'ruby enable_qdebug.rb', 16;

    assert_script_run 'wget ' . data_url('snapd_disable.rb'),  16;
    assert_script_sudo 'ruby snapd_disable.rb', 30;

    if (get_var('OPENQA_IN_CLOUD')) {
        assert_script_run 'wget ' . data_url('apt_mirror.rb'),  16;
        assert_script_sudo 'ruby apt_mirror.rb', 16;
    }

    if (get_var('SECUREBOOT')) {
        assert_script_sudo 'apt install -y mokutil', 60;
        assert_script_sudo 'mokutil --sb-state', 16;
        assert_screen 'mokutil-sb-on';
    }

    # Calamares specifically tends to meddle with the grub config, make sure
    # it contains keys we absolutely expect.
    my $cmdline = script_output('grep GRUB_CMDLINE /etc/default/grub');
    assert_script_run 'grep -E "GRUB_CMDLINE.+splash.+" /etc/default/grub',
        fail_message => "Failed to find splash key in grub cmdline!\n$cmdline";
    assert_script_run 'grep -E "GRUB_CMDLINE.+quiet.+" /etc/default/grub',
        fail_message => "Failed to find quiet key in grub cmdline!\n$cmdline";

    # Testing grub is a bit tricky because we first need to make sure it is
    # visible. To do that we'll run a fairly broad unhide script
    assert_script_run 'wget ' . data_url('grub_toggle_hide.rb'),  16;
    assert_script_sudo 'ruby grub_toggle_hide.rb', 16;
    upload_logs '/etc/default/grub';

    script_sudo 'reboot', 0;
    reset_consoles;

    # Now grub ought to be appearing.
    # Do not use the global wait limit for screenshots, otherwise we might
    # shoot past grub in the time between
    assert_screen "grub", 60, no_wait => 1;
    send_key 'ret'; # start first entry

    # Once we are on sddm, hide grub again to speed up regular boots.
    assert_screen 'sddm', 60 * 10;
    select_console 'log-console';
    assert_script_sudo 'ruby grub_toggle_hide.rb', 16;
    select_console 'x11';

    # TODO: ideally we would get ARCHIVE passed in and not run any of the
    #   setup code if not archiving. This includes, but is not limited to,
    #   the plasma and lockscreen set up.
    if (get_var('OPENQA_INSTALLATION_NONENGLISH') || get_var('TYPE') eq 'userltsedition') {
        # No use running the persistent setup for nonenglish as it isn't
        # archived. Also, nonenglish would need needles for this stuff, so
        # for the sake of us not having to write useless needles let's just
        # return early.
        return;
    }

    $self->login;
    {
        # Assert we have the correct wallpaper and then change it to a static color
        # so we don't have hugely variable needles because the translucency of
        # plasma lets the wallpaper bleed through.
        assert_screen('folder-desktop');
        mouse_set 400, 300;
        mouse_click 'right';
        assert_and_click 'plasma-context-config-folder';
        assert_and_click 'plasma-folder-config-background';
        assert_and_click 'plasma-folder-config-background-color';
        # Should the default ever become undesirable: #1d99f3 is the lovely color.
        assert_and_click 'kcm-ok';
        assert_screen('folder-desktop-color');

        # Also change the lock screen to a static color.
        # NB: this is uncomfortably similar to the wallpaper and makes matching
        #   difficult, but according to Fabian Vogt openqa only sees in black and
        #   white, so changing the color to something else wouldn't help and we'll
        #   simply have to deal with this. Should this change, #2ecc71 (greenish)
        #   is a nice color.
        x11_start_program 'kcmshell5 screenlocker' ;
        assert_screen 'kcm-screenlocker';
        assert_and_click 'kcm-screenlocker-appearance';
        assert_and_click 'kcm-screenlocker-appearance-type';
        assert_and_click 'kcm-screenlocker-appearance-type-color';
        # Should the deafault ever become undesirable: #1d99f3 is the lovely color.
        assert_and_click 'kcm-ok';
    }
    $self->logout;

    select_console 'log-console';
    script_sudo 'shutdown now', 0;
    assert_shutdown;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { milestone => 1 };
}

1;
