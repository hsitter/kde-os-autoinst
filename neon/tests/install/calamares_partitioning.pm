# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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

use base "livetest_neon";
use strict;
use testapi;
use autotest 'query_isotovideo'; # to access mouse commands directly

my $user = $testapi::username;
my $password = $testapi::password;

sub cala_setup_geoip {
    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('geoip_service_calamares.rb'),  16;
        script_sudo 'systemd-run ruby `pwd`/geoip_service_calamares.rb', 16;
    }
    select_console 'x11';
}

sub cala_welcome {
    assert_screen 'calamares-installer-welcome', 30;
    sleep(8);
    assert_and_click 'calamares-installer-next';
}

sub cala_keyboard {
    assert_screen "calamares-installer-keyboard", 16;
    sleep(8);
    assert_and_click "calamares-installer-next";
}

sub cala_show {
    assert_screen 'calamares-installer-show', 16;
}

sub cala_close {
    assert_and_click 'calamares-installer-restart-checkbox';
    assert_and_click 'calamares-installer-close';
}

sub cala_timezone {
    # Timezone has 75% fuzzyness as timezone is geoip'd so its fairly divergent.
    # Also, starting here only the top section of the window gets matched as
    # the bottom part with the buttons now has a progressbar and status
    # text which is non-deterministic.
    # NB: we give way more leeway on the new needle appearing as disk IO can
    #   cause quite a bit of slowdown and ubiquity's transition policy is
    #   fairly weird when moving away from the disk page.
    assert_screen 'calamares-installer-timezone', 60;
    sleep(8);
    assert_and_click 'calamares-installer-next';
}

sub cala_user {
    assert_screen 'calamares-installer-user', 16;
    type_string $user;
    assert_screen 'calamares-installer-user-user', 16;
    send_key 'tab'; # username field
    send_key 'tab'; # hostname field
    send_key 'tab'; # 1st password field
    type_string $password;
    send_key 'tab'; # 2nd password field
    type_string $password;
    # all fields filled (not matching hostname field)
    assert_screen 'calamares-installer-user-complete', 16;
    sleep(8);
    assert_and_click 'calamares-installer-install';
}

sub run_partioning {
    my ($code) = @_;

    assert_and_click 'calamares-installer-icon';

    cala_welcome;
    cala_timezone;
    cala_keyboard;

    assert_screen 'calamares-installer-disk', 16;
    $code->();

    cala_user;
    cala_show;
    cala_close;

    # wait for kpmcore helper to quit
    sleep 16;
}

sub run {
    my ($self) = shift;
    $self->boot;

    $testapi::username = 'neon';
    $testapi::password = '';

    cala_setup_geoip;

    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('calamares_partitioning_only.rb'),  16;
        assert_script_sudo 'ruby `pwd`/calamares_partitioning_only.rb', 16;
    }
    select_console 'x11';

    $self->maybe_switch_offline;

    # First erase and do a standard partitioning
    run_partioning sub {
        assert_and_click 'calamares-installer-disk-erase';
        assert_screen 'calamares-installer-disk-erase-selected';
        sleep(8);
        assert_and_click 'calamares-installer-next';
    };

    # Now let's replace root.
    run_partioning sub {
        assert_and_click 'calamares-installer-disk-replace';
        assert_and_click 'calamares-installer-disk-replace-select';
        assert_screen 'calamares-installer-disk-replace-selected';
        sleep(8);
        assert_and_click 'calamares-installer-next';
    };

    # Along side the other one.
    run_partioning sub {
        assert_and_click 'calamares-installer-disk-alongside';
        assert_and_click 'calamares-installer-disk-alongside-select';

        # Next adjust the spacing a bit.

        # cheeky way of getting the click area and calculating the center(
        # i.e. click point)
        my $needle = assert_screen 'calamares-installer-disk-alongside-adjust';
        my $area = $needle->{area}->[-1];
        my $x = int($area->{x} + $area->{w} / 2);
        my $y = int($area->{y} + $area->{h} / 2);

        # This has some sleeps mixed in to make sure the app registers the
        # event.
        mouse_set($x, $y);
        # mouse down
        query_isotovideo('backend_mouse_button', {button => 'left', bstate => 1});
        sleep 1;
        # move to the left
        mouse_set($x - 150, $y);
        sleep 1;
        # mouse up
        query_isotovideo('backend_mouse_button', {button => 'left', bstate => 0});
        # move it away again, lest it screws up needles via hover focus
        mouse_hide;

        assert_and_click 'calamares-installer-disk-alongside-selected';
        sleep(8);
        assert_and_click 'calamares-installer-next';
    };

    # Manually partition the shebang.
    run_partioning sub {
        assert_and_click 'calamares-installer-disk-manual';
        assert_and_click 'calamares-installer-next';
        assert_and_click 'calamares-installer-disk-manual-new-table';
        assert_and_click 'calamares-installer-disk-manual-new-gpt-ok';
        assert_screen 'calamares-installer-disk-manual-clean';
        assert_and_click 'calamares-installer-disk-manual-free-space';
        assert_and_click 'calamares-installer-disk-manual-create';

        assert_screen 'calamares-installer-disk-manual-create-dialog';
        send_key 'tab'; # fsystem
        send_key 'tab'; # encrypt?
        send_key 'tab'; # mountpoint
        type_string '/';
        # click ok
        assert_and_click 'calamares-installer-disk-manual-create-dialog';
        assert_screen 'calamares-installer-disk-manual-new-ext4-root';
        sleep(8);
        assert_and_click 'calamares-installer-next';
        assert_and_click 'calamares-installer-disk-manual-no-esp';
    };
}

sub upload_calamares_logs {
    # Uploads end up in wok/ulogs/
    # Older calamari used this path:
    upload_logs '/home/neon/.cache/Calamares/calamares/Calamares.log', failok => 1;
    # Newer this one:
    upload_logs '/home/neon/.cache/Calamares/session.log', failok => 1;
    # Even newer:
    upload_logs '/home/neon/.cache/calamares/session.log', failok => 1;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    $self->upload_calamares_logs;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;
