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

use strict;
use warnings;
use testapi;
use autotest;
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}

$testapi::username = 'user';
$testapi::password = 'password';

my $dist = testapi::get_var("CASEDIR") . '/lib/distribution_neon.pm';
require $dist;
testapi::set_distribution(distribution_neon->new());

if (testapi::get_var("INSTALLATION")) {
    my %test = (
        'devedition-gitunstable' => "tests/install_calamares.pm",
        '' => "tests/install_ubiquity.pm"
    );
    autotest::loadtest ($test{$ENV{TYPE}} || $test{''})
} elsif (testapi::get_var("TESTS_TO_RUN")) {
    for my $testpath (testapi::get_var("TESTS_TO_RUN")) {
        autotest::loadtest $testpath;
    }
} else {
    testapi::diag 'ERROR FAILURE BAD ERROR no clue what to run!';
    exit 1;
}

1;
