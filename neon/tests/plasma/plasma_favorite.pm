# Copyright (C) 2018 Bhavisha Dhruve <bhavishadhruve@gmail.com>
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

use base "basetest_neon";
use strict;
use testapi;

# Slightly changed copy of assert_and_click. Shimmy the mouse around a bit
# before clicking. This is to work around a bug in kickoff's event handling.
# Simply moving the mouse in lets kickoff only get an onEntered/onContainsMouse
# slot call. It's unclear if this is a bug/change in Qt or kickoff not being
# entirely reliable. Seeing as we have to deal with this in multiple versions
# of plasma we need a workaround all the same.
sub assert_shimmy_and_click {
    my ($mustmatch, %args) = @_;
    $args{timeout}   //= $bmwqemu::default_timeout;
    $args{button}    //= 'left';
    $args{dclick}    //= 0;
    $args{mousehide} //= 0;

    my $last_matched_needle = assert_screen($mustmatch, $args{timeout});
    bmwqemu::log_call(mustmatch => $mustmatch, %args);

    # determine click coordinates from the last area which has those explicitly specified
    my $relevant_area;
    my $relative_click_point;
    for my $area (reverse @{$last_matched_needle->{area}}) {
        next unless ($relative_click_point = $area->{click_point});

        $relevant_area = $area;
        last;
    }

    # use center of the last area if no area contains click coordinates
    if (!$relevant_area) {
        $relevant_area = $last_matched_needle->{area}->[-1];
    }
    if (!$relative_click_point || $relative_click_point eq 'center') {
        $relative_click_point = {
            xpos => $relevant_area->{w} / 2,
            ypos => $relevant_area->{h} / 2,
        };
    }

    # calculate absolute click position and click
    my $x = int($relevant_area->{x} + $relative_click_point->{xpos});
    my $y = int($relevant_area->{y} + $relative_click_point->{ypos});
    bmwqemu::diag("clicking at $x/$y");
    mouse_set($x, $y);
    mouse_set($x-1, $y);
    sleep 16; # Give a chance ot receive the movement events
    mouse_set($x+1, $y);

    if ($args{dclick}) {
        mouse_dclick($args{button}, $args{clicktime});
    }
    else {
        mouse_click($args{button}, $args{clicktime});
    }

    # move mouse back to where it was before we clicked, or to the 'hidden' position if it had never been
    # positioned
    # note: We can not move the mouse instantly. Otherwise we might end up in a click-and-drag situation.
    sleep 1;
    if ($args{mousehide}) {
        return mouse_hide();
    }
}

sub run {
    my ($self) = @_;
    assert_screen 'folder-desktop';

    # Starts the Application Launcher
    assert_and_click 'plasma-launcher';
    sleep(2);

    # Switches to the Application Tab
    assert_screen 'kickoff-favorite';
    assert_and_click 'kickoff-application';
    assert_and_click 'kickoff-office';

    # Adds Okular in the favorites tab
    assert_and_click 'kickoff-okular', button => 'right';
    assert_and_click 'kickoff-add-to-favorite';
    assert_screen 'kickoff-favorite-okular', 60;
    send_key 'esc';
    sleep(2);
    assert_and_click 'plasma-launcher';
    send_key 'esc';

    # Logging out from the session
    $self->logout;

    # Back in the session
    $self->login;
    assert_screen 'folder-desktop', 60;

    # Removes Okular from the favorites tab
    assert_and_click 'plasma-launcher', mousehide=>0;

    # NB: use a special fork of assert and click here. kickoffs event handling
    #   is weirdly off and doesn't correctly detect the active item unless
    #   we move the mouse around in the mousearea.
    assert_shimmy_and_click 'kickoff-favorite-okular', button => 'right',
                                                       timeout => 4, mousehide => 0;
    assert_and_click 'kickoff-remove-from-favorite', timeout => 4, mousehide => 0;

    if (check_screen('kickoff-favorite-okular', timeout => 2)) {
        die 'Okular should not be visible on the favorite tab'
    }

    # Close the kickoff otherwise next test will fail
    assert_and_click 'kickoff-dismiss';
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;
