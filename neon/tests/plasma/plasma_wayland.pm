# Copyright (C) 2018 Bhavisha Dhruve <bhavishadhruve@gmail.com>
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
    $self->boot;
    
    assert_and_click 'kickoff', undef, 60; # 60 seconds since we don't assert desktop
    assert_and_click 'kickoff-leave';
    assert_and_click 'kickoff-leave-logout';
    
    assert_and_click 'ksmserver-logout';
    wait_still_screen;
    
    assert_screen "sddm", 60;
  
    assert_and_click 'sddm-choose-session';
    assert_and_click 'sddm-plasma-wayland';
    
    type_password $testapi::password;
    send_key 'ret';
   
   assert_screen 'folder-desktop', 60;
    
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

sub post_fail_hook {
    
    my ($self) = shift;
    # $self->SUPER::post_fail_hook;
    
    select_console 'log-console';

    # Uploads end up in wok/ulogs/
    assert_script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
     
    upload_logs '/tmp/journal.txt';
    upload_logs '/home/$USER/.local/share/sddm/wayland-session.log';
}

1;
