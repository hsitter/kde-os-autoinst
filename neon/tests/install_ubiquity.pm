# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

sub assert_keyboard_page {
    assert_screen 'installer-keyboard', 16;

    # On bionic the keyboard is by default !english when installing !english,
    # this is a problem because we need english keyboard maps to do input
    # via openqa. So, once we've asserted the default keyboard page, change it
    # to use english instead.
    if (match_has_tag('installer-keyboard-espanol') && get_var('OPENQA_SERIES') ne 'xenial') {
        # Open the combobox
        assert_and_click 'installer-keyboard';
        # Wait for combobox to come up -.-
        sleep 8;
        # Jump close to english (ingles).
        type_string 'in';
        # At the time of writing there is a
        # crasher when selecting certain english variants, so we can't just
        # type this out. We'll move arrow down from 'in' until we have found
        # en_US.
        my $counter = 20;
        while (!check_screen('installer-keyboard-select-en-us', 1)) {
            if (!$counter--) {
                last;
            }
            send_key 'down';
            sleep 1;
        }
        assert_and_click 'installer-keyboard-select-en-us', 2;
    }

    # Make sure we've now ended up with the standard en-us keyboard setup.
    assert_screen 'installer-keyboard-en-us', 2;
    assert_and_click 'installer-next';
}

sub run {
    my ($self) = shift;
    $self->boot;

    # Divert installation data to live data.
    my $user = $testapi::username;
    my $password = $testapi::password;
    $testapi::username = 'neon';
    $testapi::password = '';

    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('geoip_service.rb'),  16;
        script_sudo 'systemd-run ruby `pwd`/geoip_service.rb', 16;
    }
    select_console 'x11';

    $self->maybe_switch_offline;

    # Installer
    assert_and_click "installer-icon";
    assert_screen "installer-welcome", 60;
    if (get_var('OPENQA_INSTALLATION_NONENGLISH')) {
        assert_and_click 'installer-welcome-click';
        send_key 'down';
        send_key 'ret';
        assert_screen 'installer-welcome-espanol';
    }
    assert_and_click "installer-next";

    # bionic version of ubiquity moved the keyboard configuration as first step
    if (testapi::get_var('OPENQA_SERIES') ne 'xenial') {
        assert_keyboard_page;
    }

    assert_screen "installer-prepare", 16;
    assert_and_click "installer-next";
    assert_screen "installer-disk", 16;
    assert_and_click "installer-install-now";
    assert_and_click "installer-disk-confirm", 'left', 16;

    # Timezone has 75% fuzzyness as timezone is geoip'd so its fairly divergent.
    # Also, starting here only the top section of the window gets matched as
    # the bottom part with the buttons now has a progressbar and status
    # text which is non-deterministic.
    # NB: we give way more leeway on the new needle appearing as disk IO can
    #   cause quite a bit of slowdown and ubiquity's transition policy is
    #   fairly weird when moving away from the disk page.
    assert_screen "installer-timezone", 60;
    assert_and_click "installer-next";

    # bionic version of ubiquity moved the keyboard configuration as first step
    # while in xenial version the keyboard config is after timezone setup
    if (testapi::get_var('OPENQA_SERIES') eq 'xenial') {
        assert_keyboard_page;
    }

    assert_screen "installer-user", 16;
    type_string $user;
    # user in user field, name field (needle doesn't include hostname in match)
    assert_screen "installer-user-user", 16;
    send_key "tab", 1; # username field
    send_key "tab", 1; # 1st password field
    type_string $password;
    send_key "tab", 1; # 2nd password field
    type_string $password;
    # all fields filled (not matching hostname field)
    assert_screen "installer-user-complete", 16;
    assert_and_click "installer-next";

    assert_screen "installer-show", 15;

    # Let install finish and restart
    assert_screen "installer-restart", 640;
    assert_and_click "installer-restart-now";

    assert_screen "live-remove-medium", 60;
    # The message actually comes up before input is read, make sure to send rets
    # until the system reboots or we've waited a bit of time. We'll then
    # continue and would fail on the first start test if the system in fact
    # never rebooted.
    my $counter = 20;
    while (check_screen('live-remove-medium', 1)) {
        if (!$counter--) {
            last;
        }
        eject_cd;
        send_key 'ret';
        sleep 1;
    }

    reset_consoles;

    # Set installation data.
    $testapi::username = $user;
    $testapi::password = $password;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    assert_script_sudo 'tar cfJ /tmp/installer.tar.xz /var/log/installer';
    upload_logs '/tmp/installer.tar.xz';
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;
