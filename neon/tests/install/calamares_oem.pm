# Copyright (C) 2016-2019 Harald Sitter <sitter@kde.org>
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

sub run {
    my ($self) = shift;
    $self->boot;

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
        script_sudo 'calamares-update', 60;

        assert_script_run 'wget ' . data_url('geoip_service_calamares.rb'),  16;
        script_sudo 'systemd-run ruby `pwd`/geoip_service_calamares.rb', 16;
    }
    select_console 'x11';

    # Installer
    assert_and_click "installer-icon";
    assert_screen "calamares-oem-welcome", 60;
    assert_and_click "calamares-installer-next";

    assert_screen "calamares-installer-timezone", 60;
    assert_and_click "calamares-installer-next";

    assert_screen "calamares-installer-keyboard", 16;
    assert_and_click "calamares-installer-next";

    assert_screen "calamares-installer-disk", 16;
    assert_and_click "calamares-installer-disk-erase";
    assert_screen "calamares-installer-disk-erase-selected", 16;
    assert_and_click "calamares-installer-next";

    # Set OEM ID. This creates a file in /var/log/installer/
    assert_and_click "calamares-oem-oemid";
    type_string 'frenchfries';
    assert_and_click "calamares-installer-next";

    assert_screen "calamares-installer-user", 16;
    type_string get_var("OEM_USERNAME");
    assert_screen "calamares-installer-user-user", 16;
    send_key "tab"; # username field
    send_key "tab"; # hostname field
    send_key "tab"; # 1st password field
    type_string get_var("OEM_PASSWORD");
    send_key "tab"; # 2nd password field
    type_string get_var("OEM_PASSWORD");
    # all fields filled (not matching hostname field)
    assert_screen "calamares-oem-user-complete", 16;
    assert_and_click "calamares-installer-next";

    assert_screen "calamares-installer-summary", 16;
    assert_and_click "calamares-installer-install";

    assert_screen "calamares-installer-show", 16;

    # Let install finish and restart
    assert_screen "calamares-installer-restart", 1200;

    # FIXME: upload_logs would need to be duped from cala test, refactor code
    #   so it can be shared
    # select_console 'log-console';
    # {
    #     $self->upload_calamares_logs;
    # }
    # select_console 'x11';

    assert_and_click "calamares-installer-restart-now";

    $self->live_reboot;

    reset_consoles;

    # Set OEM installation data.
    $testapi::username = get_var("OEM_USERNAME");
    $testapi::password = get_var("OEM_PASSWORD");

    ## #################################################### HACK
    assert_screen 'folder-desktop', 60;
    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('geoip_service_calamares.rb'),  16;
        script_sudo 'systemd-run ruby `pwd`/geoip_service_calamares.rb', 16;

        script_sudo 'calamares-update', 60;
        script_sudo 'apt install -y plasma-workspace-dbg', 120;
        script_sudo 'echo "QML_DISABLE_OPTIMIZER=1" >> /etc/environment', 120;
        script_sudo 'echo "QML_IMPORT_TRACE=1" >> /etc/environment', 120;
        assert_script_run 'wget ' . data_url('enable_qdebug.rb'),  16;
        assert_script_run 'ruby enable_qdebug.rb', 16;
        script_sudo 'systemctl restart sddm', 60;
    }
    select_console 'x11';;
    ## #################################################### HACK

    assert_screen 'oem-desktop', 60 * 3;

    sleep(60);

    # Switch into OEM mode.
    assert_and_click 'oem-prepare';
    assert_and_click 'calamares-oem-prepare-question';
    assert_screen 'calamares-oem-prepare-polkit';
    type_password;
    send_key 'ret', 1;

    # FIXME: plasmashell crashes all the flipping time when switching lnf
    #   but drkonqi then doesn't appear, probably because it thinks there is
    #   a systray to attach to. this needs fixing in drkonqi!

    # DISABLED ####################################################
    #### our current prepare auto-reboots for ease of testing
    # select_console 'log-console';
    # script_sudo 'reboot', 0;
    # DISABLED ####################################################
    # reset_consoles;

    # OEM configuration.
    assert_screen 'calamares-oem-config', 60; # needs to reboot; can take a while.

    reset_consoles;

    # FIXME: should install a service and be done with it
    select_console 'log-console';
    {
        assert_script_run 'wget ' . data_url('geoip_service_calamares.rb'),  16;
        script_sudo 'systemd-run ruby `pwd`/geoip_service_calamares.rb', 16;
        # Make sure to resatrt sddm, triggering a new autologin and thus
        # a restart of calamares. Otherwise the geoip override won't apply
        # to the running instance under test.
        script_sudo 'systemctl restart calamares-sddm';
    }
    # select_console 'x11';

    assert_screen 'calamares-oem-config';
    assert_and_click "calamares-installer-next";

    assert_screen 'calamares-installer-timezone';
    assert_and_click 'calamares-installer-next';

    assert_screen 'calamares-installer-keyboard';
    assert_and_click 'calamares-installer-next';

    assert_screen 'calamares-installer-user';
    type_string $user;
    assert_screen 'calamares-installer-user-user';
    send_key 'tab'; # username field
    send_key 'tab'; # hostname field
    send_key 'tab'; # 1st password field
    type_string $password;
    send_key "tab"; # 2nd password field
    type_string $password;
    # all fields filled (not matching hostname field)
    assert_screen 'calamares-installer-user-complete';
    assert_and_click 'calamares-installer-next';

    assert_screen 'calamares-installer-show';

    assert_and_click 'calamares-oem-config-restart', 1200;

    # Set final installation data.
    # We do this before we expect sddm. If things fail at this point the oem
    # user may no longer be functional; the final user should work fine though.
    # Otherwise a failure in the transition to sddm may result in no useful
    # data being archived.
    $testapi::username = $user;
    $testapi::password = $password;

    # NB: oem-config closes all sessions, so for all intents and purposes
    # it is like the system was restarted and we need to reset our console
    # states.
    reset_consoles;

    # Once config is done we are expected to end up on sddm.
    assert_screen 'sddm', 60 * 10;
}

sub post_fail_hook {
    # my ($self) = shift;
    # $self->SUPER::post_fail_hook;

    select_console 'log-console';

    # In case plasmashell crashed but drkonqi is still running.
    script_sudo 'killall drkonqi';

    upload_logs '/home/'.$testapi::username.'/.cache/xsession-errors', failok => 1;
    upload_logs '/home/'.$testapi::username.'/.cache/sddm/xsession-errors', failok => 1;
    upload_logs '/home/'.$testapi::username.'/.xsession-errors', failok => 1;

    upload_logs '/home/'.$testapi::username.'/.local/share/sddm/wayland-session.log', failok => 1;

    script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    upload_logs '/tmp/journal.txt', failok => 1;

    script_run 'coredumpctl info > /tmp/dumps.txt';
    upload_logs '/tmp/dumps.txt', failok => 1;

    # Uploads end up in wok/ulogs/
    # assert_script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    # upload_logs '/tmp/journal.txt';
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
