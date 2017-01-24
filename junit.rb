#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'json'
require 'jenkins_junit_builder'

# JUnit converter.
class JUnit
  # Case wrapper
  class Case < JenkinsJunitBuilder::Case
    RESULT_MAP = {
      'ok' => JenkinsJunitBuilder::Case::RESULT_PASSED,
      'fail' => JenkinsJunitBuilder::Case::RESULT_FAILURE
      # => JenkinsJunitBuilder::Case::RESULT_SKIPPED
    }.freeze

    def initialize(detail)
      super()
      self.name = detail.fetch('tags')[0] || raise
      self.result = RESULT_MAP.fetch(detail.fetch('result'))
    end
  end

  # Suite wrapper
  class Suite < JenkinsJunitBuilder::Suite
    def initialize(test_file)
      super()
      data = JSON.parse(File.read(test_file))
      self.name = File.basename(test_file).match(/result-(.+)\.json/)[1]
      self.package = name
      self.report_path = "junit/#{name}.xml"
      data.fetch('details').each do |detail|
        add_case(Case.new(detail))
      end
      add_case(meta_case(data))
    end

    def meta_case(data)
      c = JenkinsJunitBuilder::Case.new
      c.name = 'all'
      c.result = Case::RESULT_MAP.fetch(data.fetch('result'))
      c
    end
  end

  def self.from_openqa(testresults_dir)
    Dir.mkdir('junit') unless Dir.exist?('junit')
    ran = false
    Dir.glob("#{testresults_dir}/result-*.json").each do |test_file|
      ran = true
      suite = Suite.new(test_file)
      suite.write_report_file
    end
    return if ran
    raise "Could not find a single test file: #{testresults_dir}/result-*.json!"
  end
end
