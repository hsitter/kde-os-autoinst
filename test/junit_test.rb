# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative 'test_helper'
require_relative '../lib/junit'

class JUnitTest < Minitest::Test
  attr_reader :datadir

  def setup
    @datadir = File.realpath("#{__dir__}/data")
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
    JUnit.send(:remove_const, :BUILD_URL)
    JUnit.const_set(:BUILD_URL, 'http://kitten')
  end

  def teardown
    FileUtils.rm_r(@tmpdir)
  end

  def test_from_openqa
    # Purely doing coverage testing to avoid syntax errors.
    FileUtils.cp_r("#{datadir}/result-install_calamares.json", '.')
    JUnit.from_openqa(Dir.pwd)
  end

  def test_from_openqa_failure
    # Purely doing coverage testing to avoid syntax errors.
    FileUtils.cp_r("#{datadir}/result-install_calamares_failure.json", '.')
    JUnit.from_openqa(Dir.pwd)
  end
end
