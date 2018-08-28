# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
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

package basetest_neon;
use base 'basetest';

use JSON qw(decode_json);
use strict;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    # TODO: this maybe should be global as within a test series we still only
    #   use the same VM and disk, so setup actually only needs to happen once
    #   in an entire os-autoinst run.
    $self->{boot_setup_ran} = 0;
    return $self;
}

sub post_fail_hook {
    if (check_screen('drkonqi-notification', 4)) {
        assert_and_click('drkonqi-notification');
        record_soft_failure 'not implemented drkonqi opening';
    }

    if (check_screen('drkonqi-dialog', 4)) {
        assert_and_click('drkonqi-dialog');
        # FIXME: these are hacks because we don't have a needle to assert
        #  for how long the gdb tracing may take.
        sleep 12;
        send_key 'alt-f4';
        # FIXME: like above but we don't know when coredumpd is done
        sleep 12;
    }

    select_console 'log-console';

    # The next uploads are largely failok since we want to get as many logs
    # as possible evne if some are missing.
    upload_logs '/home/'.$testapi::username.'/.cache/xsession-errors', failok => 1;
    upload_logs '/home/'.$testapi::username.'/.cache/sddm/xsession-errors', failok => 1;
    upload_logs '/home/'.$testapi::username.'/.xsession-errors', failok => 1;

    upload_logs '/home/'.$testapi::username.'/.local/share/sddm/wayland-session.log', failok => 1;

    script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    upload_logs '/tmp/journal.txt', failok => 1;

    script_run 'coredumpctl info > /tmp/dumps.txt';
    upload_logs '/tmp/dumps.txt', failok => 1;

    return 1;
}

sub login {
    my ($self) = @_;
    # Short wait, we should be close to sddm if we this gets called.
    assert_screen 'sddm', 120;
    $self->maybe_login;
}

sub maybe_login {
    # Short wait, we should be close to sddm if we this gets called.
    if (check_screen 'sddm', 16) {
        type_password $testapi::password;
        send_key 'ret';
        wait_still_screen;
    }
}

sub logout {
    testapi::x11_start_program('Logout');
    assert_and_click ('ksmserver-logout');
}

sub boot_to_dm {
    my ($self, %args) = @_;
    $args{run_setup} //= 1;

    # Grub in user edition is broken as of Jan 2018 and doesn't match our needle
    # because it is shittyly themed. As we do not entirely care about this in
    # application tests we'll simply ignore it by checking for either grub or
    # sddm. Due to auto time out we'll eventually end up at sddm even if
    # we do not explicitly hit 'ret'.
    assert_screen [qw(grub sddm)], 60 * 3;
    if (match_has_tag('grub')) {
        send_key 'ret';
        assert_screen 'sddm', 60 * 2;
    }
    # else sddm, nothing to do

    if ($args{run_setup} && !$self->{boot_setup_ran}) {
        select_console 'log-console';
        {
            # Drop random file which wasn't meant to be there in xenial
            # TODO: this can e dropped after 2018-09-10 or so (once all disks
            #   rotated in the fix)
            # https://packaging.neon.kde.org/neon/settings.git/commit/?h=Neon/unstable_xenial&id=dc28d791e5e4432174dca9a02eccecebccf024b0
            if (get_var('OPENQA_SERIES') ne 'xenial') {
              script_sudo 'rm /etc/apt/preferences.d/99-neon-qca';
            }

            assert_script_run 'wget ' . data_url('basetest_setup.rb'),  60;
            assert_script_sudo 'ruby basetest_setup.rb', 60;

            # FIXME: copy pasta from install core.pm
            if (get_var('OPENQA_APT_UPGRADE')) {
                assert_script_sudo 'apt update',  2 * 60;
                my $pkgs = get_var('OPENQA_APT_UPGRADE');
                if ($pkgs eq "all") {
                    $pkgs = "dist-upgrade";
                } else {
                    $pkgs = "install " . $pkgs;
                }
                assert_script_sudo 'DEBIAN_FRONTEND=noninteractive apt -y ' . $pkgs, 30 * 60;
            }
        }
        select_console 'x11';
        $self->{boot_setup_ran} = 1;
    }

    # Move mouse to make sure sddm isn't idle before we return.
    # Make sure to hide it afterwards, lest it triggers hovers.
    mouse_set(1, 1);
    mouse_hide;
}

# Waits for system to boot and log in (no assertion about desktop).
sub boot {
    my ($self, $args) = @_;

    $self->boot_to_dm;
    $self->login;
}

# Switches to log-console and reboots the system via 'reboot'
sub reboot {
    select_console 'log-console';
    script_sudo 'reboot', 0;
    reset_consoles;
}

sub enable_snapd {
    my ($self, %args) = @_;

    $args{auto_install_snap} //= 0;

    select_console 'log-console';
    assert_script_sudo 'systemctl enable --now snapd.service';

    # When turning on snapd it may schedule a whole bunch of stuff to update.
    # Wait until all automatic changes are done. To establish that talk to
    # the API and get in-progress changes.
    my @changes = ();
    do {
        sleep 8;
        my $changes_json = script_output 'curl --unix-socket /run/snapd.socket http:/v2/changes?select=in-progress';
        @changes = @{decode_json($changes_json)->{result}};
    } while (@changes);

    my $runtime = 'kde-frameworks-5';
    my $snap = get_var('OPENQA_SNAP_NAME');
    my $snap_channel = get_var('OPENQA_SNAP_CHANNEL');
    my $runtime_channel = get_var('OPENQA_SNAP_RUNTIME_CHANNEL');
    if ($runtime_channel eq "" || !defined $runtime_channel) {
        $runtime_channel = get_var('OPENQA_SNAP_CHANNEL');
    }
    if ($runtime_channel eq "" || !defined $runtime_channel) {
        $runtime_channel = "stable";
    }
    assert_script_sudo "snap switch --$runtime_channel $runtime";
    assert_script_sudo 'snap refresh', 30 * 60;
    script_run "snap info $runtime > /tmp/runtime.info";
    upload_logs '/tmp/runtime.info';
    assert_script_run "curl --unix-socket /run/snapd.socket http:/v2/snaps/$runtime > /tmp/runtime.json";
    upload_logs '/tmp/runtime.json';
    if ($args{auto_install_snap}) {
        assert_script_sudo "snap install --$snap_channel $snap", 15 * 60;
        script_run "snap info $snap > /tmp/snap.info";
        upload_logs '/tmp/snap.info';
        assert_script_run "curl --unix-socket /run/snapd.socket http:/v2/snaps/$snap > /tmp/snap.json";
        upload_logs '/tmp/snap.json';
    }

    assert_script_run 'curl --unix-socket /run/snapd.socket http:/v2/interfaces > /tmp/interfaces.json';
    upload_logs '/tmp/interfaces.json';

    select_console 'x11';
}

sub enable_snapd_and_install_snap {
    my ($self, $args) = @_;
    return $self->enable_snapd(auto_install_snap => 1);
}

1;
