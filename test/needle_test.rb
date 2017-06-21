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

NEEDLE_DIR = File.realpath("#{__dir__}/../neon/needles")

class NeedleTest < Minitest::Test
  def assert_path_exist(path, msg = nil)
    msg = message(msg) { "Expected path '#{path}' to exist" }
    assert File.exist?(path), msg
  end

  def refute_path_exist(path, msg = nil)
    msg = message(msg) { "Expected path '#{path}' to NOT exist" }
    refute File.exist?(path), msg
  end

  Dir.glob("#{NEEDLE_DIR}/**/*.json").each do |json|
    basename = File.basename(json)
    base = File.basename(json, '.json')

    define_method("test_has_png_#{basename}") do
      dir = File.dirname(json)
      png = "#{dir}/#{base}.png"
      assert_path_exist(png, "needle #{base} has no png [#{png}]")
    end

    # NB: technically a basename of the tag is also qualifying. for now
    #   we have no reason to use this though so this assertion should hold
    #   until we find a use for more generic tagging.
    define_method("test_has_tag_#{basename}") do
      data = JSON.parse(File.read(json))
      assert_includes data.fetch('tags'), base
    end
  end

  Dir.glob("#{NEEDLE_DIR}/**/*.png").each do |png|
    basename = File.basename(png)
    base = File.basename(png, '.png')

    define_method("test_has_json_#{basename}") do
      dir = File.dirname(png)
      json = "#{dir}/#{base}.json"
      assert_path_exist(json, "needle #{base} has no json [#{json}]")
    end
  end
end
