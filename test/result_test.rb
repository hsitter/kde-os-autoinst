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
require_relative '../lib/result'

module OSAutoInst
  class ResultSuiteTest < Minitest::Test
    @@datadir = File.realpath("#{__dir__}/data/results")

    attr_reader :datadir

    def setup
      @datadir = @@datadir
      @tmpdir = Dir.mktmpdir
      Dir.chdir(@tmpdir)
    end

    def teardown
      FileUtils.rm_r(@tmpdir)
    end

    def test_init
      ResultSuite.new("#{datadir}/result-first_start.json")
    end

    # factorize
    Dir.glob(File.join(@@datadir, '*')).each do |needle|
      basename = File.basename(needle)
      next if basename.start_with?('result-') # skip full test sets
      next if basename.start_with?('test_order.json') # also suites
      define_method("test_needle_#{needle}") do
        json = JSON.parse(File.read(needle), symbolize_names: true)
        p DetailFactory.new(json).factorize
      end
    end
  end
end
