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

use warnings;
use testapi;
use autotest;
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}

$testapi::username = 'user';
$testapi::password = 'password';
testapi::set_var('OEM_USERNAME', 'oem');
testapi::set_var('OEM_PASSWORD', 'oem');

my $dist = testapi::get_var("CASEDIR") . '/lib/distribution_neon.pm';
require $dist;
testapi::set_distribution(distribution_neon->new());

if (testapi::get_var("INSTALLATION")) {
    my %test = (
        'devedition-gitunstable' => "tests/install_calamares.pm",
        '' => "tests/install_ubiquity.pm"
    );
    autotest::loadtest('tests/install/bootloader.pm');
    autotest::loadtest('tests/install/core.pm');
    if (testapi::get_var("INSTALLATION_OEM")) {
        autotest::loadtest('tests/install/ubiquity_oem.pm');
    } else {
        autotest::loadtest($test{$ENV{TYPE}} || $test{''});
    }
    autotest::loadtest('tests/install/first_start.pm');
} elsif (testapi::get_var("TESTS_TO_RUN")) {
    my $testpaths = testapi::get_var("TESTS_TO_RUN");
    for my $testpath (@$testpaths) {
        autotest::loadtest $testpath;
    }
} elsif (testapi::get_var("PLASMA_DESKTOP")) {
    autotest::loadtest('tests/plasma/plasma_folder.pm');
    autotest::loadtest('tests/plasma/plasma_lockscreen.pm');
} else {
    testapi::diag 'ERROR FAILURE BAD ERROR no clue what to run!';
    exit 1;
}

1;
