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

# use testapi qw/check_var get_var set_var/;
# use lockapi;
# use needle;

use strict;
use warnings;
use testapi;
use autotest;
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}

$testapi::username = 'neon';
$testapi::password = '';

my $distri = testapi::get_var("CASEDIR") . '/lib/distribution_neon.pm';
require $distri;
testapi::set_distribution(distribution_neon->new());

autotest::loadtest "tests/install_ubiquity.pm";

1;

# vim: set sw=4 et:
