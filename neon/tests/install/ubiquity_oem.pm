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

use base "basetest";
use testapi;

sub run {
    # Divert installation data to live data.
    my $user = $testapi::username;
    my $password = $testapi::password;
    $testapi::username = 'neon';
    $testapi::password = '';

    # wait for the desktop to appear
    assert_screen 'live-desktop', 360;

    # The oem installation itself also a tz selection, its different from the
    # oem-config though (which we'll intercept below, separately).
    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('geoip_service.rb'),  16;
        script_sudo 'systemd-run ruby `pwd`/geoip_service.rb', 16;
    }
    select_console 'x11';

    # Installer
    assert_and_click "installer-icon";
    assert_screen "oem-installer-welcome", 60;
    record_soft_failure 'ubiquity tab order is wrong, continue before oem label';
    send_key 'tab'; # continue button
    send_key 'tab'; # language combobox
    send_key 'tab'; # oem label
    type_string 'frenchfries';
    assert_and_click "installer-next";
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
    assert_screen "installer-keyboard", 16;
    assert_and_click "installer-next";

    assert_screen "oem-installer-user", 16;
    # We are in the password field already. Username is oem by default
    type_string get_var("OEM_PASSWORD");
    send_key "tab", 1; # 2nd password field
    type_string get_var("OEM_PASSWORD");
    # all fields filled (not matching hostname field)
    assert_screen "oem-installer-user-complete", 16;
    assert_and_click "installer-next";

    assert_screen "installer-show", 10;

    # Let install finish and restart
    assert_screen "installer-restart", 60 * 15;
    assert_and_click "installer-restart-now";

    assert_screen "live-remove-medium", 60;
    send_key "ret";

    reset_consoles;

    # Set OEM installation data.
    $testapi::username = get_var("OEM_USERNAME");
    $testapi::password = get_var("OEM_PASSWORD");

    assert_screen 'oem-desktop', 60 * 3;

    # TODO: should be moved ot some lib thingy for re-use across tests
    # This is done here because we needn't have oem-config running as it'd lock
    # the database so we can't change the tz config anymore.
    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('geoip_service.rb'),  16;
        script_sudo 'systemd-run ruby `pwd`/geoip_service.rb', 16;
    }
    select_console 'x11';
    assert_screen 'oem-desktop';

    # Switch into OEM mode.
    assert_and_click 'oem-prepare';
    assert_screen 'oem-prepare-polkit';
    type_password;
    send_key 'ret', 1;

    select_console 'log-console';
    script_sudo 'reboot', 0;
    reset_consoles;

    # OEM configuration.
    assert_screen 'oem-config', 60 * 3; # needs to reboot; can take a while.

    # FIXME: should install a service and be done with it
    select_console 'log-console';
    {
        script_sudo 'systemd-run ruby `pwd`/geoip_service.rb', 16;
    }
    select_console 'oem-config'; # Runs on tty1 actually. != x11
    assert_screen 'oem-config';

    assert_and_click "installer-next";

    assert_screen 'oem-config-timezone';
    assert_and_click "installer-next";

    assert_screen 'oem-config-keyboard';
    assert_and_click "installer-next";

    assert_screen "oem-config-user", 16;
    type_string $user;
    # user in user field, name field (needle doesn't include hostname in match)
    assert_screen "oem-config-user-user", 16;
    send_key "tab", 1; # username field
    send_key "tab", 1; # 1st password field
    type_string $password;
    send_key "tab", 1; # 2nd password field
    type_string $password;
    # all fields filled (not matching hostname field)
    assert_screen "oem-config-user-complete", 16;
    assert_and_click "installer-next";

    assert_screen "oem-config-show", 10;

    # NB: oem-config closes all sessions, so for all intents and purposes
    # it is like the system was restarted and we need to reset our console
    # states.
    reset_consoles;

    # Once config is done we are expected to end up on sddm.
    assert_screen 'sddm', 60 * 10;

    # Set final installation data.
    $testapi::username = $user;
    $testapi::password = $password;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    select_console 'log-console';

    # Uploads end up in wok/ulogs/
    assert_script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    upload_logs '/tmp/journal.txt';
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
